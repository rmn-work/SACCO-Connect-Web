from django import forms
from .models import TransactionHistory, Pret, Membres as Membre, Partenaire, CollaborateurPartenaire
from django.contrib.auth.models import User, Group
from django.contrib.auth.forms import UserCreationForm
from django.contrib.auth.models import User


class PartnerMemberOnboardingForm(forms.ModelForm):
    class Meta:
        model = Membre
        fields = ['nom', 'prenom', 'telephone', 'cni', 'colline', 'quartier', 'groupe', 'solde_epargne']
        widgets = {
            'nom': forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'Nom'}),
            'prenom': forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'Prénom'}),
            'telephone': forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'Téléphone'}),
            'cni': forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'Numéro CNI'}),
            'colline': forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'Colline'}),
            'quartier': forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'Quartier'}),
            'groupe': forms.Select(attrs={'class': 'form-control'}),
            'solde_epargne': forms.NumberInput(attrs={'class': 'form-control'}),
        }


class PartnerProfileForm(forms.ModelForm):
    class Meta:
        model = Partenaire
        fields = ['nom', 'email', 'telephone', 'adresse']
        widgets = {
            'nom': forms.TextInput(attrs={'class': 'form-control'}),
            'email': forms.EmailInput(attrs={'class': 'form-control'}),
            'telephone': forms.TextInput(attrs={'class': 'form-control'}),
            'adresse': forms.Textarea(attrs={'class': 'form-control', 'rows': 3}),
        }


class TransactionForm(forms.ModelForm):
    class Meta:
        model = TransactionHistory
        fields = ['membre', 'montant', 'type_operation', 'statut', 'description']
        widgets = {
            'membre': forms.Select(attrs={'class': 'w-full border border-gray-300 rounded p-2'}),
            'montant': forms.NumberInput(attrs={'class': 'w-full border border-gray-300 rounded p-2', 'placeholder': 'Ex: 50000'}),
            'type_operation': forms.Select(attrs={'class': 'w-full border border-gray-300 rounded p-2'}),
            'statut': forms.TextInput(attrs={'class': 'w-full border border-gray-300 rounded p-2'}),
            'description': forms.Textarea(attrs={'class': 'w-full border border-gray-300 rounded p-2', 'rows': 3}),
        }

    def clean_montant(self):
        montant = self.cleaned_data.get('montant')
        type_operation = self.cleaned_data.get('type_operation')
        membre = self.cleaned_data.get('membre')

        if montant is not None and montant <= 0:
            raise forms.ValidationError("Le montant de la transaction doit être supérieur à zéro.")

        if type_operation == 'RETRAIT' and membre and montant:
            if montant > membre.solde_epargne:
                raise forms.ValidationError(
                    f"Solde insuffisant pour ce retrait. Solde actuel du membre : {membre.solde_epargne} BIF."
                )

        return montant


class EmployeeCreationForm(UserCreationForm):
    role = forms.ModelChoiceField(
        queryset=Group.objects.all(),
        required=True,
        label="Rôle de l'employé",
        empty_label="Sélectionnez un rôle"
    )

    class Meta(UserCreationForm.Meta):
        model = User
        fields = UserCreationForm.Meta.fields + ('email', 'first_name', 'last_name')

    def save(self, commit=True):
        user = super().save(commit=False)

        if commit:
            user.save()
            selected_group = self.cleaned_data['role']
            user.groups.add(selected_group)

        return user


class LoanRequestForm(forms.ModelForm):
    motif = forms.CharField(
        label="Motif de la demande de prêt",
        widget=forms.Textarea(attrs={
            'rows': 3,
            'placeholder': 'Expliquez brièvement la raison de votre demande (ex: investissement, santé, étude...)',
            'class': 'w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm'
        }),
        required=True
    )

    class Meta:
        model = Pret
        fields = ['montant', 'duree_mois', 'motif']
        labels = {
            'montant': 'Montant du prêt (BIF)',
            'duree_mois': 'Durée de remboursement (mois)',
        }
        widgets = {
            'montant': forms.NumberInput(attrs={
                'class': 'w-full p-2 border rounded focus:ring-2 focus:ring-blue-500',
                'placeholder': 'Ex: 500000'
            }),
            'duree_mois': forms.NumberInput(attrs={
                'class': 'w-full p-2 border rounded focus:ring-2 focus:ring-blue-500',
                'placeholder': 'Ex: 12'
            }),
        }

    def __init__(self, *args, **kwargs):
        self.membre = kwargs.pop('membre', None)
        super().__init__(*args, **kwargs)

    def clean_montant(self):
        montant = self.cleaned_data.get('montant')
        if self.membre and montant:
            epargne = self.membre.solde_epargne or 0
            plafond = epargne * 5
            if montant > plafond:
                raise forms.ValidationError(
                    f"Le montant ne peut pas dépasser 5 fois votre épargne ({plafond:,.0f} BIF max)."
                )
        return montant


class CollaborateurCreationForm(forms.ModelForm):
    username = forms.CharField(
        label="Nom d'utilisateur",
        widget=forms.TextInput(attrs={'class': 'form-control'})
    )
    password = forms.CharField(
        label="Mot de passe",
        widget=forms.PasswordInput(attrs={'class': 'form-control'})
    )
    email = forms.EmailField(
        label="Email",
        widget=forms.EmailInput(attrs={'class': 'form-control'})
    )

    class Meta:
        model = CollaborateurPartenaire
        fields = ['role']
        widgets = {
            'role': forms.Select(attrs={'class': 'form-control'}),
        }

    def save(self, commit=True, partenaire=None):
        user = User.objects.create_user(
            username=self.cleaned_data['username'], email=self.cleaned_data['email'],
            password=self.cleaned_data['password']
        )
        collaborateur = super().save(commit=False)
        collaborateur.user = user
        collaborateur.partenaire = partenaire
        if commit:
            collaborateur.save()
        return collaborateur

class PartnerDepositForm(forms.ModelForm):
    class Meta:
        model = TransactionHistory
        fields = ['membre', 'montant', 'description']
        widgets = {
            'membre': forms.Select(attrs={'class': 'form-control'}),
            'montant': forms.NumberInput(attrs={'class': 'form-control', 'placeholder': 'Ex: 50000'}),
            'description': forms.Textarea(attrs={'class': 'form-control', 'rows': 3}),
        }

    def clean_montant(self):
        montant = self.cleaned_data.get('montant')
        if montant is not None and montant <= 0:
            raise forms.ValidationError("Le montant du dépôt doit être supérieur à zéro.")
        return montant