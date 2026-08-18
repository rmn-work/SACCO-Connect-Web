import logging
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth.models import User, Group
from .models import TransactionHistory
from .utils import send_member_notification

logger = logging.getLogger(__name__)


@receiver(post_save, sender=TransactionHistory)
def notify_transaction_created(sender, instance, created, **kwargs):
    if created:
        membre = instance.membre
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


@receiver(post_save, sender=User)
def assign_default_group(sender, instance, created, **kwargs):
    if created and not instance.is_superuser:
        group, _ = Group.objects.get_or_create(name='Caissiers')
        instance.groups.add(group)
        logger.info(f"[SYSTEM] L'utilisateur {instance.username} a été ajouté au groupe 'Caissiers'.")