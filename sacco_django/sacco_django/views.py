from django.db import transaction
from django.db.models import F, Sum
from django.shortcuts import render, get_object_or_404, redirect
from django.contrib import messages
from django.http import JsonResponse
from datetime import datetime

# Importations depuis l'application 'core'
from core.models import Membres as Membre, TransactionHistory, HistoriqueEpargne
from core.forms import TransactionForm


def ajouter_transaction(request, membre_id):
    membre = get_object_or_404(Membre, pk=membre_id)

    if request.method == 'POST':
        form = TransactionForm(request.POST)
        if form.is_valid():
            try:
                tx = form.save(commit=False)
                tx.membre = membre

                if tx.type_transaction == 'RETRAIT' and membre.solde_epargne < tx.montant:
                    messages.error(
                        request,
                        f"Opération refusée : Solde insuffisant. (Solde actuel : {membre.solde_epargne})"
                    )
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


def api_profil_complet_view(request, membre_id):
    try:
        membre = Membre.objects.select_related('groupe').get(id=membre_id)

        # Calcul des totaux d'épargne et caisse sociale
        totaux = HistoriqueEpargne.objects.filter(membre=membre).aggregate(
            sum_epargne=Sum('montant_epargne'),
            sum_social=Sum('montant_social')
        )
        solde_epargne_val = totaux['sum_epargne'] if totaux['sum_epargne'] is not None else (
                    getattr(membre, 'solde_epargne', 0) or 0)
        caisse_sociale_val = totaux['sum_social'] if totaux['sum_social'] is not None else (
                    getattr(membre, 'caisse_sociale', 0) or 0)

        # Dernière réunion
        dernier_historique = HistoriqueEpargne.objects.filter(membre=membre).order_by('-id').first()
        date_derniere = "Non définie"
        if dernier_historique:
            raw_derniere = getattr(dernier_historique, 'date_reunion', None) or getattr(dernier_historique, 'date',
                                                                                        None)
            if raw_derniere:
                if hasattr(raw_derniere, 'strftime'):
                    date_derniere = raw_derniere.strftime('%d/%m/%Y')
                else:
                    date_derniere = str(raw_derniere)[:10]

        groupe = membre.groupe
        date_prochaine_fr = "À déterminer"
        montant_hebdo_val = "5000"
        president_val = "N/D"
        secretaire_val = "N/D"
        admin_sys_val = "N/D"

        if groupe:
            raw_prochaine = getattr(groupe, 'date_reunion_prochaine', None) or getattr(groupe, 'prochaine_reunion',
                                                                                       None)
            if raw_prochaine and str(raw_prochaine).strip():
                if hasattr(raw_prochaine, 'strftime'):
                    date_prochaine_fr = raw_prochaine.strftime('%d/%m/%Y à %H:%M')
                else:
                    raw_str = str(raw_prochaine).replace('T', ' ').strip()
                    try:
                        if len(raw_str) >= 16:
                            dt = datetime.strptime(raw_str[:16], '%Y-%m-%d %H:%M')
                            date_prochaine_fr = dt.strftime('%d/%m/%Y à %H:%M')
                        else:
                            dt = datetime.strptime(raw_str[:10], '%Y-%m-%d')
                            date_prochaine_fr = dt.strftime('%d/%m/%Y')
                    except ValueError:
                        date_prochaine_fr = raw_str

            cotis = getattr(groupe, 'cotisation_hebdo_fixee', None)
            if cotis and str(cotis) != '0':
                montant_hebdo_val = str(cotis)

            responsables = Membre.objects.filter(groupe=groupe).filter(
                role__icontains='resident'
            ) | Membre.objects.filter(groupe=groupe, role__icontains='cretaire'
                                      ) | Membre.objects.filter(groupe=groupe, role__icontains='admin')

            for resp in responsables:
                role_lower = (resp.role or '').lower()
                nom_complet = f"{getattr(resp, 'nom', '')} {getattr(resp, 'prenom', '')}".strip()

                if 'resident' in role_lower and president_val == "N/D":
                    president_val = nom_complet
                elif 'cretaire' in role_lower and secretaire_val == "N/D":
                    secretaire_val = nom_complet
                elif 'admin' in role_lower and admin_sys_val == "N/D":
                    admin_sys_val = nom_complet

        data = {
            "id": membre.id,
            "nom": getattr(membre, 'nom', '') or '',
            "prenom": getattr(membre, 'prenom', '') or '',
            "telephone": getattr(membre, 'telephone', '') or '',
            "role": getattr(membre, 'role', 'MEMBRE'),
            "groupe_id": groupe.id if groupe else '',

            "solde_epargne": float(solde_epargne_val),
            "caisse_sociale": float(caisse_sociale_val),
            "montant_caisse_sociale": float(caisse_sociale_val),

            "date_reunion_prochaine": date_prochaine_fr,
            "prochaine_reunion": date_prochaine_fr,

            "groupe": {
                "date_reunion_derniere": date_derniere,
                "date_reunion_prochaine": date_prochaine_fr,
                "prochaine_reunion": date_prochaine_fr,
                "montant_hebdo": montant_hebdo_val,
                "cotisation_fixe": montant_hebdo_val,
                "president": president_val,
                "secretaire": secretaire_val,
                "admin_sys": admin_sys_val,
            }
        }
        return JsonResponse({"status": "success", "data": data})

    except Membre.DoesNotExist:
        return JsonResponse({"status": "error", "message": "Membre non trouvé"}, status=404)