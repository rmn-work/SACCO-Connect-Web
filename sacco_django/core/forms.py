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
        fields = ['montant', 'duree_mois', 'motif']
        widgets = {
            'montant': forms.NumberInput(attrs={'class': 'w-full border border-gray-200 rounded-xl p-2.5 text-sm focus:outline-none focus:border-blue-500', 'placeholder': 'Ex: 100000'}),
            'duree_mois': forms.NumberInput(attrs={'class': 'w-full border border-gray-200 rounded-xl p-2.5 text-sm focus:outline-none focus:border-blue-500', 'placeholder': 'Ex: 3'}),
            'motif': forms.Textarea(attrs={'class': 'w-full border border-gray-200 rounded-xl p-2.5 text-sm focus:outline-none focus:border-blue-500', 'rows': 3, 'placeholder': 'Précisez le motif du prêt...'}),
        }

    def __init__(self, *args, **kwargs):
        self.membre = kwargs.pop('membre', None)
        super().__init__(*args, **kwargs)

    def clean_montant(self):
        montant = self.cleaned_data.get('montant')
        if self.membre and self.membre.solde_epargne is not None:
            solde_max_autorise = self.membre.solde_epargne * 3
            if montant and montant > solde_max_autorise:
                raise forms.ValidationError(
                    f"Le montant demandé dépasse votre plafond autorisé ({solde_max_autorise} BIF basé sur votre épargne)."
                )
        return montant