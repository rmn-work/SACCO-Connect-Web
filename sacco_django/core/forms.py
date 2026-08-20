from django import forms
from .models import TransactionHistory, Pret
from django.contrib.auth.models import User, Group
from django.contrib.auth.forms import UserCreationForm


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
    class Meta:
        model = Pret
        fields = ['montant', 'duree_mois']
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