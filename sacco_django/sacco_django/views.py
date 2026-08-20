from django.db import transaction
from django.db.models import F
from django.shortcuts import render, get_object_or_404, redirect
from django.contrib import messages
from .models import Membre, Transaction
from .forms import TransactionForm


def ajouter_transaction(request, membre_id):
    membre = get_object_or_404(Membre, pk=membre_id)

    if request.method == 'POST':
        form = TransactionForm(request.POST)
        if form.is_valid():
            try:
                tx = form.save(commit=False)
                tx.membre = membre

                if tx.type_transaction == 'RETRAIT' and membre.solde_epargne < tx.montant:
                    messages.error(request,
                                   f"Opération refusée : Solde insuffisant. (Solde actuel : {membre.solde_epargne})")
                    return render(request, 'core/ajouter_transaction.html', {'form': form, 'membre': membre})

                with transaction.atomic():
                    tx.save()

                    if tx.type_transaction == 'DEPOT':
                        Membre.objects.filter(pk=membre.pk).update(
                            solde_epargne=F('solde_epargne') + tx.montant
                        )
                        messages.success(request, f"✅ Dépôt de {tx.montant} enregistré avec succès.")

                    elif tx.type_transaction == 'RETRAIT':
                        Membre.objects.filter(pk=membre.pk).update(
                            solde_epargne=F('solde_epargne') - tx.montant
                        )
                        messages.success(request, f"✅ Retrait de {tx.montant} enregistré avec succès.")

                return redirect('dashboard_admin')

            except Exception as e:
                messages.error(request, f"❌ Une erreur critique est survenue : {str(e)}")
    else:
        form = TransactionForm()

    return render(request, 'core/ajouter_transaction.html', {'form': form, 'membre': membre})