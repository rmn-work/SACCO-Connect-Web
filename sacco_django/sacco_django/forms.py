from django import forms
from .models import Transaction

class TransactionForm(forms.ModelForm):
    class Meta:
        model = Transaction
        fields = ['montant', 'type_transaction', 'description']
        widgets = {
            'montant': forms.NumberInput(attrs={'class': 'form-control', 'placeholder': 'Montant en BIF'}),
            'type_transaction': forms.Select(attrs={'class': 'form-control'}),
            'description': forms.TextInput(attrs={'class': 'form-control'}),
        }