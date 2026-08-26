from decimal import Decimal
from django.core.validators import MinValueValidator
from django.db import models
from django.utils import timezone
from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    ROLE_CHOICES = (
        ('member', 'Membre'),
        ('partner', 'Partenaire'),
        ('admin', 'Administrateur'),
    )

    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='member')

    groups = models.ManyToManyField(
        'auth.Group',
        verbose_name='groups',
        blank=True,
        help_text='The groups this user belongs to.',
        related_name='core_user_groups',
        related_query_name='core_user',
    )

    user_permissions = models.ManyToManyField(
        'auth.Permission',
        verbose_name='user permissions',
        blank=True,
        help_text='Specific permissions for this user.',
        related_name='core_user_permissions',
        related_query_name='core_user',
    )

    @property
    def is_partner(self):
        return self.role == 'partner'

    @property
    def is_member(self):
        return self.role == 'member'

class Partenaire(models.Model):
    nom = models.CharField(max_length=150, verbose_name="Nom du partenaire")
    code_partenaire = models.CharField(max_length=20, unique=True, verbose_name="Code unique")
    email = models.EmailField(max_length=255, blank=True, null=True, verbose_name="Email")
    telephone = models.CharField(max_length=20, blank=True, null=True, verbose_name="Téléphone")
    adresse = models.TextField(blank=True, null=True, verbose_name="Adresse physique")
    date_creation = models.DateTimeField(auto_now_add=True, verbose_name="Date d'enregistrement")
    est_actif = models.BooleanField(default=True, verbose_name="Compte actif")

    def __str__(self):
        return f"{self.nom} ({self.code_partenaire})"


class Amendes(models.Model):
    groupe_id = models.IntegerField(blank=True, null=True)
    membre = models.ForeignKey('Membres', models.DO_NOTHING, blank=True, null=True)
    motif = models.TextField(blank=True, null=True)
    montant_a_payer = models.FloatField(blank=True, null=True)
    montant_paye = models.FloatField(blank=True, null=True)
    date_enregistrement = models.TextField(blank=True, null=True)
    enregistre_par = models.TextField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'amendes'

class DecaissementSocial(models.Model):
    groupe_id = models.IntegerField(blank=True, null=True)
    membre = models.ForeignKey('Membres', models.DO_NOTHING, blank=True, null=True)
    objet = models.TextField(blank=True, null=True)
    date_decaissement = models.TextField(blank=True, null=True)
    montant_decaisse = models.FloatField(blank=True, null=True)
    montant_rembourse = models.FloatField(blank=True, null=True)
    enregistre_par = models.TextField(blank=True, null=True)
    heure_enregistrement = models.TextField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'decaissement_social'

class DemandesSociales(models.Model):
    membre_id = models.IntegerField(blank=True, null=True)
    montant_demande = models.FloatField(blank=True, null=True)
    motif = models.TextField(blank=True, null=True)
    status = models.TextField(blank=True, null=True)
    date_demande = models.TextField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'demandes_sociales'

class DemandeCredit(models.Model):
    membre = models.ForeignKey('Membres', on_delete=models.CASCADE)
    montant = models.DecimalField(max_digits=12, decimal_places=2)
    duree_mois = models.IntegerField()
    motif = models.TextField()
    statut = models.CharField(max_length=20, default='En attente', choices=[
        ('En attente', 'En attente'),
        ('Approuvé', 'Approuvé'),
        ('Rejeté', 'Rejeté')
    ])
    date_demande = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Prêt de {self.montant} BIF - {self.membre.prenom} {self.membre.nom}"

class Groupes(models.Model):
    id = models.AutoField(primary_key=True)
    nom_groupe = models.TextField(blank=True, null=True)
    president_id = models.IntegerField(blank=True, null=True)
    secretaire_id = models.IntegerField(blank=True, null=True)
    est_archive = models.BooleanField(default=False)
    #partenaire = models.ForeignKey(Partenaire, on_delete=models.SET_NULL, null=True, blank=True, verbose_name="Partenaire associé")
    cotisation_hebdo_fixee = models.DecimalField(max_digits=65535, decimal_places=65535, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'groupes'
        verbose_name = "Groupe"
        verbose_name_plural = "Groupes"

class HistoriqueEpargne(models.Model):
    membre = models.ForeignKey('Membres', models.DO_NOTHING, blank=True, null=True)
    groupe_id = models.IntegerField(blank=True, null=True)
    montant = models.FloatField(blank=True, null=True)
    montant_epargne = models.FloatField(blank=True, null=True)
    montant_social = models.FloatField(blank=True, null=True)
    date_reunion = models.TextField(blank=True, null=True)
    heure_enregistrement = models.TextField(blank=True, null=True)
    enregistre_par = models.TextField(blank=True, null=True)
    caisse_sociale = models.DecimalField(max_digits=65535, decimal_places=65535, blank=True, null=True)
    epargne = models.DecimalField(max_digits=65535, decimal_places=65535, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'historique_epargne'

class HistoriqueSocial(models.Model):
    membre = models.ForeignKey('Membres', models.DO_NOTHING, blank=True, null=True)
    groupe_id = models.IntegerField(blank=True, null=True)
    montant = models.FloatField(blank=True, null=True)
    date_reunion = models.TextField(blank=True, null=True)
    heure_enregistrement = models.TextField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'historique_social'

class JournalPrets(models.Model):
    groupe_id = models.IntegerField(blank=True, null=True)
    membre = models.ForeignKey('Membres', models.DO_NOTHING, blank=True, null=True)
    objet = models.TextField(blank=True, null=True)
    date_decaissement = models.TextField(blank=True, null=True)
    date_echeance = models.TextField(blank=True, null=True)
    montant_decaisse = models.FloatField(blank=True, null=True)
    interet = models.FloatField(blank=True, null=True)
    total_a_payer = models.FloatField(blank=True, null=True)
    montant_paye = models.FloatField(blank=True, null=True)
    solde = models.FloatField(blank=True, null=True)
    date_paiement = models.TextField(blank=True, null=True)
    commentaire = models.TextField(blank=True, null=True)
    enregistre_par = models.TextField(blank=True, null=True)

    class Meta:
        managed = False
        db_table='journal_prets'

class Logs(models.Model):
    utilisateur = models.TextField(blank=True, null=True)
    action = models.TextField(blank=True, null=True)
    details = models.TextField(blank=True, null=True)
    date = models.TextField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'logs'

class Membres(models.Model):
    ROLE_CHOICES = [
        ('membre', 'Membre'), ('president', 'Président de groupe'), ('secretaire', 'Secrétaire de groupe'),
    ]
    id = models.AutoField(primary_key=True)
    nom = models.TextField(blank=True, null=True)
    prenom = models.TextField(blank=True, null=True)
    age = models.IntegerField(blank=True, null=True)
    sexe = models.TextField(blank=True, null=True)
    telephone = models.TextField(unique=True, blank=True, null=True)
    cni = models.TextField(blank=True, null=True)
    colline = models.TextField(blank=True, null=True)
    quartier = models.TextField(blank=True, null=True)
    avenue = models.TextField(blank=True, null=True)
    maison = models.TextField(blank=True, null=True)
    pin = models.TextField(blank=True, null=True)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='membre', blank=True, null=True)
    groupe = models.ForeignKey(
        'Groupes', on_delete=models.SET_NULL, null=True, blank=True, default=1, db_column='groupe_id')
    doit_changer_pin = models.IntegerField(blank=True, null=True)
    solde_epargne = models.FloatField(blank=True, null=True)
    solde_pret = models.FloatField(blank=True, null=True)
    is_active = models.IntegerField(blank=True, null=True)
    caisse_sociale = models.FloatField(blank=True, null=True)
    last_login = models.TextField(blank=True, null=True)
    last_login_app = models.TextField(blank=True, null=True)
    status_presence = models.TextField(blank=True, null=True)
    credit_en_cours = models.FloatField(blank=True, null=True)
    credit_rembourse = models.FloatField(blank=True, null=True)
    credit_restant = models.FloatField(blank=True, null=True)
    solde_pret_social = models.FloatField(blank=True, null=True)

    def __str__(self):
        nom_val = self.nom or ""
        prenom_val = self.prenom or ""
        return f"{nom_val} {prenom_val} ({self.get_role_display()})"

    class Meta:
        managed = False
        db_table = 'membres'
        verbose_name = "Membre"
        verbose_name_plural = "Membres"

class Presences(models.Model):
    membre_id = models.IntegerField(blank=True, null=True)
    groupe_id = models.IntegerField(blank=True, null=True)
    date_reunion = models.TextField(blank=True, null=True)
    status = models.TextField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'presences'

class Pret(models.Model):
    STATUT_CHOICES = [
        ('EN_ATTENTE', 'En attente'), ('APPROUVE', 'Approuvé'), ('REJETE', 'Rejeté'), ('SOLDE', 'Soldé'),
        ('EN_ATTENTE_AGENT', 'En attente de vérification (Agent)'), ('EN_ATTENTE_DIRECTEUR', 'En attente d approbation (Directeur)'),
    ]

    membre = models.ForeignKey(
        'Membres', on_delete=models.CASCADE, related_name='prets')
    montant = models.DecimalField(
        max_digits=12, decimal_places=2, validators=[MinValueValidator(0)], help_text='Montant demandé en BIF',)
    taux_interet = models.DecimalField(max_digits=5, decimal_places=2, help_text="Taux d'intérêt trimestriel en %")
    duree_mois = models.PositiveIntegerField(help_text='Durée de remboursement en mois')
    statut = models.CharField(max_length=50, choices=STATUT_CHOICES, default='EN_ATTENTE')
    motif = models.TextField(verbose_name="Motif de la demande", blank=True, null=True)
    date_demande = models.DateTimeField(auto_now_add=True)
    date_approbation = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name = 'Prêt'
        verbose_name_plural = 'Prêts'
        ordering = ['-date_demande']

    def __str__(self):
        return f'Prêt #{self.id} - {self.membre.nom} {self.montant} BIF'

    def montant_total_a_rembourser(self):
        montant = Decimal(str(self.montant))
        taux = Decimal(str(self.taux_interet))
        duree = Decimal(str(self.duree_mois))
        interets = (montant * taux * (duree / Decimal('3'))) / Decimal('100')
        return montant + interets


class TransactionHistory(models.Model):
    TYPE_CHOICES = [
        ('DEPOT', 'Dépôt'), ('RETRAIT', 'Retrait'), ('PENALITE', 'Pénalité de retard'), ('Octroi de Crédit', 'Octroi de Crédit'),
        ('Remboursement Crédit', 'Remboursement Crédit'),
    ]

    membre = models.ForeignKey(
        Membres, on_delete=models.CASCADE, related_name='transactions')
    montant = models.DecimalField(max_digits=12, decimal_places=2)
    type_operation = models.CharField(max_length=50, choices=TYPE_CHOICES, default='DEPOT')
    statut = models.CharField(max_length=20, default='ACTIF')
    description = models.CharField(max_length=255, blank=True, null=True)
    date_transaction = models.DateTimeField(default=timezone.now)

    def __str__(self):
        nom_complet = f"{self.membre.nom or ''} {self.membre.prenom or ''}".strip()
        return f"{self.type_operation} - {nom_complet} - {self.montant} BIF"

    class Meta:
        ordering = ['-date_transaction']


class DemandePret(models.Model):
    membre = models.ForeignKey('Membres', on_delete=models.CASCADE, related_name='demandes_pret')
    montant = models.DecimalField(max_digits=12, decimal_places=2)
    motif = models.TextField()
    statut = models.CharField(
        max_length=20, choices=[('en_attente', 'En attente'), ('approuve', 'Approuvé'), ('rejete', 'Rejeté')],
        default='en_attente')
    date_demande = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Prêt de {self.montant} BIF - {self.membre.nom}"