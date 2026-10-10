from decimal import Decimal
from django.db import models
from django.db.models import Sum
from django.utils import timezone
from django.core.validators import MinValueValidator
from django.contrib.auth.models import AbstractUser, User
from django import forms

# ==============================================================================
# MODÈLE UTILISATEUR ET PARTENAIRES
# ==============================================================================

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


class PartnerSettingsForm(forms.ModelForm):
    telephone = forms.CharField(
        max_length=20,
        required=False,
        widget=forms.TextInput(attrs={'class': 'w-full px-4 py-2.5 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none'})
    )

    class Meta:
        model = User
        fields = ['first_name', 'last_name', 'email', 'telephone']
        widgets = {
            'first_name': forms.TextInput(attrs={'class': 'w-full px-4 py-2.5 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none'}),
            'last_name': forms.TextInput(attrs={'class': 'w-full px-4 py-2.5 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none'}),
            'email': forms.EmailInput(attrs={'class': 'w-full px-4 py-2.5 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none'}),
        }

    def clean_email(self):
        email = self.cleaned_data.get('email')
        if email and self.instance:
            if User.objects.filter(email=email).exclude(pk=self.instance.pk).exists():
                raise forms.ValidationError("Cet e-mail est déjà utilisé par un autre compte.")
        return email


# ==============================================================================
# MODÈLES UNMANAGED (STRUCTURE LEGACY / TABLES EXISTANTES)
# ==============================================================================

class Groupes(models.Model):
    id = models.AutoField(primary_key=True)
    nom_groupe = models.TextField(blank=True, null=True)
    president_id = models.IntegerField(blank=True, null=True)
    secretaire_id = models.IntegerField(blank=True, null=True)
    est_archive = models.BooleanField(default=False)
    partenaire = models.ForeignKey(
        'Partenaire', on_delete=models.SET_NULL, null=True, blank=True, verbose_name="Partenaire associé"
    )
    cotisation_hebdo_fixee = models.DecimalField(max_digits=12, decimal_places=2, blank=True, null=True)
    taux_interet_reunion = models.DecimalField(max_digits=5, decimal_places=2, default=5.00)
    date_reunion_derniere = models.CharField(max_length=50, blank=True, null=True)
    date_reunion_prochaine = models.CharField(max_length=50, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'groupes'
        verbose_name = "Groupe"
        verbose_name_plural = "Groupes"

    def __str__(self):
        return self.nom_groupe or f"Groupe #{self.id}"

    @property
    def total_caisse_sociale_groupe(self):
        return TransactionHistory.objects.filter(
            membre__groupe=self, type_operation='CAISSE_SOCIALE'
        ).aggregate(total=Sum('montant'))['total'] or 0.0

    @property
    def total_decaissements_groupe(self):
        return DecaissementSocial.objects.filter(
            groupe_id=self.id
        ).aggregate(total=Sum('montant_decaisse'))['total'] or 0.0

    @property
    def solde_caisse_sociale_groupe(self):
        return max(0.0, self.total_caisse_sociale_groupe - self.total_decaissements_groupe)


class Membres(models.Model):
    ROLE_CHOICES = [
        ('membre', 'Membre'),
        ('president', 'Président de groupe'),
        ('secretaire', 'Secrétaire de groupe'),
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
        Groupes, on_delete=models.SET_NULL, null=True, blank=True, default=1, db_column='groupe_id'
    )
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

    class Meta:
        managed = False
        db_table = 'membres'
        verbose_name = "Membre"
        verbose_name_plural = "Membres"

    def __str__(self):
        nom_val = self.nom or ""
        prenom_val = self.prenom or ""
        return f"{nom_val} {prenom_val} ({self.get_role_display()})".strip()

    @property
    def total_amendes(self):
        return TransactionHistory.objects.filter(
            membre=self, type_operation='AMENDE'
        ).aggregate(total=Sum('montant'))['total'] or 0.0

    @property
    def total_caisse_sociale(self):
        return TransactionHistory.objects.filter(
            membre=self, type_operation='CAISSE_SOCIALE'
        ).aggregate(total=Sum('montant'))['total'] or 0.0

    @property
    def total_depots(self):
        return TransactionHistory.objects.filter(
            membre=self, type_operation='DEPOT'
        ).aggregate(total=Sum('montant'))['total'] or 0.0

    @property
    def total_presences(self):
        return Presences.objects.filter(
            membre_id=self.id,
            status__in=['P', 'p', 'PRESENT', 'Present', 'present']
        ).count()

    @property
    def total_absences(self):
        return Presences.objects.filter(
            membre_id=self.id,
            status__in=['A', 'a', 'ABSENT', 'Absent', 'absent']
        ).count()

    @property
    def total_excuses(self):
        return Presences.objects.filter(
            membre_id=self.id,
            status__in=['E', 'e', 'EX', 'ex', 'EXCUSE', 'Excusé', 'excuse']
        ).count()

    @property
    def total_cotisation_sociale(self):
        return TransactionHistory.objects.filter(
            membre=self, type_operation='CAISSE_SOCIALE'
        ).aggregate(total=Sum('montant'))['total'] or 0.0

    @property
    def total_decaissements_social(self):
        return DecaissementSocial.objects.filter(
            membre=self
        ).aggregate(total=Sum('montant_decaisse'))['total'] or 0.0

    @property
    def solde_caisse_sociale(self):
        cotisation = Decimal(str(self.total_cotisation_sociale or 0))
        decaissement = Decimal(str(self.total_decaissements_social or 0))
        return float(max(Decimal('0'), cotisation - decaissement))

    @property
    def calculer_credits(self):
        prets_attribues = self.prets.filter(
            statut__in=['ATTRIBUE', 'attribut', 'APPROUVE', 'approuve'],
            est_archive=False
        )
        total_en_cours = sum([float(p.montant_total_a_rembourser()) for p in prets_attribues])
        total_rembourse = TransactionHistory.objects.filter(
            membre=self, type_operation__in=['Remboursement Crédit', 'remboursement crédit', 'REMBOURSEMENT']
        ).aggregate(total=Sum('montant'))['total'] or 0.0
        restant = max(0.0, total_en_cours - float(total_rembourse))
        return {
            'en_cours': total_en_cours,
            'rembourse': float(total_rembourse),
            'restant': restant
        }

# ==============================================================================
# FORMULAIRES MÉTIER
# ==============================================================================

class MembreForm(forms.ModelForm):
    SEXE_CHOICES = [
        ('M', 'Masculin'),
        ('F', 'Féminin'),
    ]

    sexe = forms.ChoiceField(
        choices=SEXE_CHOICES,
        widget=forms.Select(attrs={'class': 'w-full px-4 py-2.5 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 bg-white outline-none'})
    )

    class Meta:
        model = Membres
        fields = [
            'nom', 'prenom', 'sexe', 'age', 'cni', 'pin',
            'telephone', 'colline', 'quartier', 'avenue',
            'maison', 'groupe', 'solde_epargne'
        ]
        widgets = {
            'nom': forms.TextInput(attrs={'class': 'w-full px-4 py-2.5 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none', 'placeholder': 'Nom'}),
            'prenom': forms.TextInput(attrs={'class': 'w-full px-4 py-2.5 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none', 'placeholder': 'Prénom'}),
            'age': forms.NumberInput(attrs={'class': 'w-full px-4 py-2.5 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none', 'placeholder': 'Âge'}),
            'cni': forms.TextInput(attrs={'class': 'w-full px-4 py-2.5 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none', 'placeholder': 'Numéro CNI'}),
            'pin': forms.PasswordInput(attrs={'class': 'w-full px-4 py-2.5 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none', 'placeholder': 'Code PIN provisoire'}),
            'telephone': forms.TextInput(attrs={'class': 'w-full px-4 py-2.5 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none', 'placeholder': 'Téléphone'}),
            'colline': forms.TextInput(attrs={'class': 'w-full px-4 py-2.5 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none', 'placeholder': 'Colline'}),
            'quartier': forms.TextInput(attrs={'class': 'w-full px-4 py-2.5 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none', 'placeholder': 'Quartier'}),
            'avenue': forms.TextInput(attrs={'class': 'w-full px-4 py-2.5 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none', 'placeholder': 'Avenue'}),
            'maison': forms.TextInput(attrs={'class': 'w-full px-4 py-2.5 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none', 'placeholder': 'Numéro de maison'}),
            'groupe': forms.Select(attrs={'class': 'w-full px-4 py-2.5 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 bg-white outline-none'}),
            'solde_epargne': forms.NumberInput(attrs={'class': 'w-full px-4 py-2.5 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none', 'step': '0.01'}),
        }


class CollaborateurPartenaire(models.Model):
    ROLE_CHOICES = [
        ('ADMIN', 'Administrateur Partenaire'),
        ('OPERATEUR', 'Opérateur de Saisie'),
    ]

    partenaire = models.ForeignKey(Partenaire, on_delete=models.CASCADE, related_name='collaborateurs')
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='OPERATEUR')
    date_creation = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} ({self.get_role_display()}) - {self.partenaire.nom}"


class HistoriqueEpargne(models.Model):
    membre = models.ForeignKey(Membres, on_delete=models.CASCADE, related_name='historiques_epargne')
    groupe_id = models.IntegerField(blank=True, null=True)
    montant = models.FloatField(blank=True, null=True)
    montant_epargne = models.FloatField(blank=True, null=True)
    montant_social = models.FloatField(blank=True, null=True)
    date_reunion = models.TextField(blank=True, null=True)
    heure_enregistrement = models.TextField(blank=True, null=True)
    enregistre_par = models.TextField(blank=True, null=True)
    caisse_sociale = models.DecimalField(max_digits=12, decimal_places=2, blank=True, null=True)
    epargne = models.DecimalField(max_digits=12, decimal_places=2, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'historique_epargne'


class Amendes(models.Model):
    groupe_id = models.IntegerField(blank=True, null=True)
    membre = models.ForeignKey(Membres, models.DO_NOTHING, blank=True, null=True)
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
    membre = models.ForeignKey(Membres, models.DO_NOTHING, blank=True, null=True)
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


class HistoriqueSocial(models.Model):
    membre = models.ForeignKey(Membres, models.DO_NOTHING, blank=True, null=True)
    groupe_id = models.IntegerField(blank=True, null=True)
    montant = models.FloatField(blank=True, null=True)
    date_reunion = models.TextField(blank=True, null=True)
    heure_enregistrement = models.TextField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'historique_social'


class JournalPrets(models.Model):
    groupe_id = models.IntegerField(blank=True, null=True)
    membre = models.ForeignKey(Membres, models.DO_NOTHING, blank=True, null=True)
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
        db_table = 'journal_prets'


class Logs(models.Model):
    utilisateur = models.TextField(blank=True, null=True)
    action = models.TextField(blank=True, null=True)
    details = models.TextField(blank=True, null=True)
    date = models.TextField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'logs'


class Presences(models.Model):
    membre_id = models.IntegerField(blank=True, null=True)
    groupe_id = models.IntegerField(blank=True, null=True)
    date_reunion = models.TextField(blank=True, null=True)
    status = models.TextField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'presences'


# ==============================================================================
# MODÈLES MANAGED (GESTION INTERNE DJANGO)
# ==============================================================================

class Pret(models.Model):
    STATUT_CHOICES = [
        ('EN_ATTENTE', 'En attente'),
        ('APPROUVE', 'Approuvé (Accordé)'),
        ('ATTRIBUE', 'Attribué (Viré / Versé)'),
        ('REJETE', 'Rejeté'),
        ('SOLDE', 'Soldé'),
        ('EN_ATTENTE_AGENT', 'En attente de vérification (Agent)'),
        ('EN_ATTENTE_DIRECTEUR', 'En attente d approbation (Directeur)'),
    ]

    membre = models.ForeignKey(Membres, on_delete=models.CASCADE, related_name='prets')
    montant = models.DecimalField(
        max_digits=12, decimal_places=2, validators=[MinValueValidator(0)], help_text='Montant demandé en BIF'
    )
    taux_interet = models.DecimalField(max_digits=5, decimal_places=2, help_text="Taux d'intérêt trimestriel en %")
    duree_mois = models.PositiveIntegerField(help_text='Durée de remboursement en mois')
    statut = models.CharField(max_length=50, choices=STATUT_CHOICES, default='EN_ATTENTE')
    est_archive = models.BooleanField(default=False, verbose_name="Archivé")
    motif = models.TextField(verbose_name="Motif de la demande", blank=True, null=True)
    date_demande = models.DateTimeField(auto_now_add=True)
    date_approbation = models.DateTimeField(null=True, blank=True)
    date_traitement = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name = 'Prêt'
        verbose_name_plural = 'Prêts'
        ordering = ['-date_demande']

    def __str__(self):
        return f'Prêt #{self.id} - {self.membre.nom} {self.montant} BIF'

    def montant_total_a_rembourser(self):
        montant = Decimal(str(self.montant))
        taux = Decimal(str(self.membre.groupe.taux_interet_reunion)) if (self.membre and self.membre.groupe and self.membre.groupe.taux_interet_reunion) else Decimal(str(self.taux_interet))
        duree = Decimal(str(self.duree_mois))
        interets = (montant * taux * (duree / Decimal('3'))) / Decimal('100')
        return montant + interets


class DemandeCredit(models.Model):
    membre = models.ForeignKey(Membres, on_delete=models.CASCADE)
    montant = models.DecimalField(max_digits=12, decimal_places=2)
    duree_mois = models.IntegerField()
    motif = models.TextField()
    statut = models.CharField(
        max_length=20,
        default='En attente',
        choices=[('En attente', 'En attente'), ('Approuvé', 'Approuvé'), ('Rejeté', 'Rejeté')]
    )
    date_demande = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Prêt de {self.montant} BIF - {self.membre.prenom} {self.membre.nom}"


class DemandePret(models.Model):
    membre = models.ForeignKey(Membres, on_delete=models.CASCADE, related_name='demandes_pret')
    montant = models.DecimalField(max_digits=12, decimal_places=2)
    motif = models.TextField()
    statut = models.CharField(
        max_length=20,
        choices=[('en_attente', 'En attente'), ('approuve', 'Approuvé'), ('rejete', 'Rejeté')],
        default='en_attente'
    )
    date_demande = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Prêt de {self.montant} BIF - {self.membre.nom}"


class TransactionHistory(models.Model):
    TYPE_CHOICES = [
        ('DEPOT', 'Dépôt'),
        ('RETRAIT', 'Retrait'),
        ('AMENDE', 'Amende'),
        ('CAISSE_SOCIALE', 'Caisse Sociale'),
        ('PENALITE', 'Pénalité de retard'),
        ('Octroi de Crédit', 'Octroi de Crédit'),
        ('Remboursement Crédit', 'Remboursement Crédit'),
    ]

    STATUT_CHOICES = [
        ('EN_ATTENTE', 'En attente de validation'),
        ('VALIDE', 'Validé'),
        ('REJETE', 'Rejeté'),
    ]

    membre = models.ForeignKey('Membres', on_delete=models.CASCADE, related_name='transactions')
    montant = models.DecimalField(max_digits=12, decimal_places=2)
    type_operation = models.CharField(max_length=50, choices=TYPE_CHOICES, default='DEPOT')
    provider = models.CharField(max_length=20, null=True, blank=True)
    statut = models.CharField(max_length=20, choices=STATUT_CHOICES, default='EN_ATTENTE')
    valide_par = models.ForeignKey(User, null=True, blank=True, on_delete=models.SET_NULL,
                                   related_name='transactions_validees')
    date_validation = models.DateTimeField(null=True, blank=True)
    description = models.TextField(blank=True, null=True)
    date_transaction = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ['-date_transaction']

    def __str__(self):
        nom_complet = f"{self.membre.nom or ''} {self.membre.prenom or ''}".strip()
        return f"{self.type_operation} - {nom_complet} - {self.montant} BIF ({self.statut})"

    @property
    def motif(self):
        return self.description


class TicketSupport(models.Model):
    sujet = models.CharField(max_length=255)
    membre = models.ForeignKey(Membres, on_delete=models.CASCADE, related_name='tickets')
    partenaire_assigne = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, blank=True, related_name='tickets_partenaire'
    )
    date_creation = models.DateTimeField(auto_now_add=True)
    est_resolu = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.sujet} - {self.membre.nom} {self.membre.prenom}"


class MessageTicket(models.Model):
    ticket = models.ForeignKey(TicketSupport, on_delete=models.CASCADE, related_name='messages')
    expediteur_membre = models.ForeignKey(Membres, on_delete=models.CASCADE, null=True, blank=True)
    expediteur_user = models.ForeignKey(User, on_delete=models.CASCADE, null=True, blank=True)
    contenu = models.TextField()
    date_envoi = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['date_envoi']

class CycleFinancier(models.Model):
    nom = models.CharField(max_length=100) # Ex: "Exercice 2026"
    date_debut = models.DateField()
    date_fin = models.DateField(null=True, blank=True)
    est_cloture = models.BooleanField(default=False)
    date_cloture = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        statut = 'Clôturé' if self.est_cloture else 'Actif'
        return f"{self.nom} ({statut})"

class JournalAudit(models.Model):
    utilisateur = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    action = models.CharField(max_length=255)
    details = models.TextField(blank=True, null=True)
    adresse_ip = models.GenericIPAddressField(null=True, blank=True)
    date_action = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"[{self.date_action.strftime('%d/%m/%Y %H:%M')}] {self.action}"

class JournalLog(models.Model):
    utilisateur = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    action = models.CharField(max_length=255)
    details = models.TextField(blank=True, null=True)
    date_action = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-date_action']

    def __str__(self):
        return f"{self.date_action} - {self.action} ({self.utilisateur})"

class ParametreSysteme(models.Model):
    cle = models.CharField(max_length=100, unique=True)
    valeur = models.TextField()

    def __str__(self):
        return f"{self.cle} = {self.valeur}"


# ==============================================================================
# ALIASES DE MAPPING
# ==============================================================================

Membre = Membres
Groupe = Groupes
Transaction = TransactionHistory
Presence = Presences