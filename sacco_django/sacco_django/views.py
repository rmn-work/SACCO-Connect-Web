from django.db import transaction
from django.db.models import F
from django.shortcuts import render, get_object_or_404, redirect
from .models import Membre, Transaction
from .forms import TransactionForm

def ajouter_transaction(request, membre_id):
    membre = get_object_or_404(Membre, pk=membre_id)

    if request.method == 'POST':
        form = TransactionForm(request.POST)
        if form.is_valid():
            try:
                with transaction.atomic():
                    tx = form.save(commit=False)
                    tx.membre = membre
                    tx.save()

                    if tx.type_transaction == 'DEPOT':
                        Membre.objects.filter(pk=membre.pk).update(
                            solde_epargne=F('solde_epargne') + tx.montant
                        )
                    elif tx.type_transaction == 'RETRAIT':
                        Membre.objects.filter(pk=membre.pk).update(
                            solde_epargne=F('solde_epargne') - tx.montant
                        )

                return redirect('dashboard_admin')
            except Exception as e:
                pass
    else:
        form = TransactionForm()

    return render(request, 'core/ajouter_transaction.html', {'form': form, 'membre': membre})