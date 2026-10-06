import logging
from decimal import Decimal
from django.db.models import Sum
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from django.contrib.auth.models import User, Group
from django.contrib.auth.signals import user_logged_in
from .models import TransactionHistory, Membre, Groupe, DecaissementSocial, JournalLog
from .utils import send_member_notification

logger = logging.getLogger(__name__)

def recalculer_soldes_membre(membre):
    if not membre:
        return

    total_cotisations_caisse = TransactionHistory.objects.filter(
        membre=membre,
        type_operation='CAISSE_SOCIALE'
    ).aggregate(total=Sum('montant'))['total'] or Decimal('0')

    total_decaissements = DecaissementSocial.objects.filter(
        membre=membre
    ).aggregate(total=Sum('montant_decaisse'))['total'] or Decimal('0')

    membre.caisse_sociale = float(max(Decimal('0'), total_cotisations_caisse - Decimal(str(total_decaissements))))

    total_epargne = TransactionHistory.objects.filter(
        membre=membre,
        type_operation='EPARGNE'
    ).aggregate(total=Sum('montant'))['total'] or Decimal('0')  # <-- Correction ici

    membre.solde_epargne = float(total_epargne)
    membre.save(update_fields=['caisse_sociale', 'solde_epargne'])


@receiver(post_save, sender=TransactionHistory)
@receiver(post_delete, sender=TransactionHistory)
def handle_transaction_changes(sender, instance, created=False, **kwargs):
    membre = instance.membre

    if created and membre:
        message = (
            f"SACCO Connect: Bonjour {membre.prenom}, "
            f"votre operation de {instance.type_operation} d'un montant de "
            f"{instance.montant} BIF a bien ete enregistree. Statut: {instance.statut}."
        )
        try:
            send_member_notification(membre, message)
            logger.info(f"[SYSTEM] Notification envoyée à {membre.prenom} pour la transaction {instance.id}.")
        except Exception as e:
            logger.error(f"[ERREUR] Échec de l'envoi de la notification à {membre.prenom} : {e}")

    recalculer_soldes_membre(membre)


@receiver(post_save, sender=DecaissementSocial)
@receiver(post_delete, sender=DecaissementSocial)
def handle_decaissement_changes(sender, instance, **kwargs):
    recalculer_soldes_membre(instance.membre)


@receiver(post_save, sender=User)
def assign_default_group(sender, instance, created, **kwargs):
    if created and not instance.is_superuser:
        group, _ = Group.objects.get_or_create(name='Caissiers')
        instance.groups.add(group)
        logger.info(f"[SYSTEM] L'utilisateur {instance.username} a été ajouté au groupe 'Caissiers'.")


@receiver(user_logged_in)
def log_user_login(sender, request, user, **kwargs):
    try:
        JournalLog.objects.create(
            utilisateur=user,
            action="Connexion",
            details=f"L'utilisateur {user.username} s'est connecté avec succès."
        )
        logger.info(f"[SYSTEM] Journal d'audit créé pour la connexion de {user.username}.")
    except Exception as e:
        logger.error(f"[ERREUR] Impossible d'enregistrer la connexion de {user.username} : {e}")


@receiver(post_save, sender=Membre)
def assigner_groupe_par_defaut(sender, instance, created, **kwargs):
    if created and not instance.groupe:
        premier_groupe = Groupe.objects.first()
        if premier_groupe:
            instance.groupe = premier_groupe
            instance.save(update_fields=['groupe'])