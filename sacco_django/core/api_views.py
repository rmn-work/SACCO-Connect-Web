import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth import authenticate, login
from django.contrib.auth.models import User
from .models import Membre, Pret, TransactionHistory


@csrf_exempt
def api_login_view(request):
    if request.method == 'OPTIONS':
        return JsonResponse({'success': True}, status=200)

    if request.method != 'POST':
        return JsonResponse({'success': False, 'message': 'Méthode non autorisée'}, status=405)

    try:
        data = json.loads(request.body)
        telephone = data.get('username') or data.get('telephone')
        pin = data.get('pin') or data.get('password')

        if not telephone or not pin:
            return JsonResponse({'success': False, 'message': 'Téléphone et PIN requis'}, status=400)

        membre = Membre.objects.filter(telephone=telephone).first()

        if not membre:
            return JsonResponse({'success': False, 'message': 'Numéro de téléphone introuvable'}, status=400)

        if str(membre.pin) == str(pin):
            user = getattr(membre, 'user', None)
            if not user:
                user, _ = User.objects.get_or_create(username=telephone)
                membre.user = user
                membre.save()

            login(request, user)

            return JsonResponse({
                'success': True,
                'message': 'Connexion réussie',
                'membre_id': membre.id,
                'user_id': user.id,
                'username': f"{membre.nom} {membre.prenom}".strip()
            })
        else:
            return JsonResponse({'success': False, 'message': 'Code PIN ou identifiants incorrects'}, status=400)

    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)}, status=400)


@csrf_exempt
def api_dashboard_view(request, membreId):
    print(f"🔍 [DJANGO API] Appel de api_dashboard_view pour le membre ID: {membreId}")
    try:
        membre = Membre.objects.get(id=membreId)
        is_active = getattr(membre, 'is_active', 1) == 1

        # Récupération des données via les propriétés intelligentes du modèle Membres
        credits_dict = membre.calculer_credits

        data = {
            'nom_complet': f"{membre.nom or ''} {membre.prenom or ''}".strip(),
            'solde_epargne': float(membre.solde_epargne or 0.0),
            'statut': 'Actif' if is_active else 'Inactif',
            'groupe_id': membre.groupe_id if membre.groupe_id else 1,

            # Caisse Sociale
            'caisse_sociale_cotisations': float(membre.total_cotisation_sociale),
            'caisse_sociale_decaissements': float(membre.total_decaissements_social),
            'caisse_sociale_nette': float(membre.solde_caisse_sociale),

            # Indicateurs de Crédits
            'credit_en_cours': float(credits_dict['en_cours']),
            'credit_rembourse': float(credits_dict['rembourse']),
            'credit_restant': float(credits_dict['restant']),
        }
        print(f"📦 [DJANGO API] Données prêtes à être envoyées : {data}")
        return JsonResponse({'success': True, 'data': data})
    except Membre.DoesNotExist:
        print(f"❌ [DJANGO API] Membre ID {membreId} introuvable.")
        return JsonResponse({'success': False, 'message': 'Membre non trouvé'}, status=404)


@csrf_exempt
def api_profil_membre(request, membreId):
    try:
        membre = Membre.objects.get(id=membreId)
        data = {
            'id': membre.id,
            'nom': membre.nom,
            'prenom': membre.prenom,
            'telephone': membre.telephone,
            'colline': getattr(membre, 'colline', ''),
            'quartier': getattr(membre, 'quartier', ''),
        }
        return JsonResponse({'success': True, 'data': data})
    except Membre.DoesNotExist:
        return JsonResponse({'success': False, 'message': 'Membre non trouvé'}, status=404)


@csrf_exempt
def api_credits_actifs(request, membreId):
    try:
        credits = Pret.objects.filter(membre_id=membreId, statut__in=['ATTRIBUE', 'APPROUVE'])
        data = []
        for c in credits:
            attr = getattr(c, 'montant_total_a_rembourser', c.montant)
            val_total = attr() if callable(attr) else attr
            data.append({
                'id': c.id,
                'montant': float(c.montant),
                'montant_total': float(val_total),
            })
        return JsonResponse({'success': True, 'data': data})
    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)}, status=400)


@csrf_exempt
def api_upload_recu(request, membreId):
    if request.method == 'POST':
        try:
            membre = Membre.objects.get(id=membreId)
            recu_file = request.FILES.get('recu')
            if recu_file and hasattr(membre, 'recu'):
                membre.recu = recu_file
                membre.save()
            return JsonResponse({'success': True, 'message': 'Reçu téléversé avec succès !'})
        except Membre.DoesNotExist:
            return JsonResponse({'success': False, 'message': 'Membre introuvable'}, status=404)
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'success': False, 'message': 'Méthode non autorisée'}, status=405)


@csrf_exempt
def api_demande_credit(request, membreId):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            membre = Membre.objects.get(id=membreId)
            montant = data.get('montant') or data.get('montant_demande', 0)
            motif = data.get('motif') or data.get('detailed_credit_reason', '')

            pret = Pret.objects.create(
                membre=membre,
                montant=montant,
                motif=motif,
                statut='EN_ATTENTE'
            )
            return JsonResponse({'success': True, 'message': 'Demande de crédit enregistrée', 'pret_id': pret.id},
                                status=201)
        except Membre.DoesNotExist:
            print(f"❌ Erreur : Membre ID {membreId} introuvable.")
            return JsonResponse({'success': False, 'message': 'Membre introuvable'}, status=404)
        except Exception as e:
            print(f"❌ Erreur validation formulaire / JSON (Crédit) : {e}")
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'success': False, 'message': 'Méthode non autorisée'}, status=405)


@csrf_exempt
def api_demande_sociale(request, membreId):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            membre = Membre.objects.get(id=membreId)
            montant = data.get('montant_demande') or data.get('montant', 0)
            raw_motif = data.get('motif') or data.get('reason_social', '')

            pret = Pret.objects.create(
                membre=membre,
                montant=montant,
                motif=f"[Social] {raw_motif}",
                statut='EN_ATTENTE'
            )
            return JsonResponse({'success': True, 'message': 'Demande sociale enregistrée', 'pret_id': pret.id},
                                status=201)
        except Membre.DoesNotExist:
            print(f"❌ Erreur : Membre ID {membreId} introuvable.")
            return JsonResponse({'success': False, 'message': 'Membre introuvable'}, status=404)
        except Exception as e:
            print(f"❌ Erreur validation formulaire / JSON (Social) : {e}")
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'success': False, 'message': 'Méthode non autorisée'}, status=405)


@csrf_exempt
def api_mes_demandes_prets(request, membreId):
    try:
        prets = Pret.objects.filter(membre_id=membreId).order_by('-id')
        data = [{
            'id': p.id,
            'montant': float(p.montant),
            'statut': getattr(p, 'statut', 'EN_ATTENTE'),
            'motif': getattr(p, 'motif', ''),
        } for p in prets]
        return JsonResponse({'success': True, 'data': data})
    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)}, status=400)


@csrf_exempt
def api_historique_membre(request, membreId):
    try:
        transactions = TransactionHistory.objects.filter(membre_id=membreId).order_by('-id')
        data = [{
            'id': t.id,
            'montant': float(t.montant),
            'type_operation': getattr(t, 'type_operation', ''),
            'description': getattr(t, 'description', ''),
        } for t in transactions]
        return JsonResponse({'success': True, 'data': data})
    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)}, status=400)


@csrf_exempt
def api_inscription_membre(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            telephone = data.get('telephone') or data.get('phone')

            if Membre.objects.filter(telephone=telephone).exists():
                return JsonResponse({'success': False, 'message': 'Ce numéro existe déjà.'}, status=400)

            membre = Membre.objects.create(
                nom=data.get('nom') or data.get('fullName', ''),
                prenom=data.get('prenom', ''),
                age=data.get('age', 18),
                sexe=data.get('sexe', 'M'),
                telephone=telephone,
                cni=data.get('cni', ''),
                colline=data.get('colline', ''),
                quartier=data.get('quartier', ''),
                pin=data.get('pin')
            )

            return JsonResponse({'success': True, 'message': 'Inscription réussie !', 'membre_id': membre.id}, status=201)
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'success': False, 'message': 'Méthode non autorisée'}, status=405)


@csrf_exempt
def api_enregistrer_remboursement(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            credit_id = data.get('credit_id')
            montant = float(data.get('montant', 0))

            pret = Pret.objects.get(id=credit_id)

            TransactionHistory.objects.create(
                membre=pret.membre,
                montant=montant,
                type_operation='Remboursement Crédit',
                description=f"Remboursement du prêt #{pret.id}"
            )

            if hasattr(pret.membre, 'solde_pret') and pret.membre.solde_pret:
                actuel = float(pret.membre.solde_pret)
                pret.membre.solde_pret = max(0.0, actuel - montant)
                pret.membre.save()

            return JsonResponse({'success': True, 'message': 'Remboursement enregistré avec succès !'})
        except Pret.DoesNotExist:
            return JsonResponse({'success': False, 'message': 'Crédit introuvable.'}, status=404)
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'success': False, 'message': 'Méthode non autorisée'}, status=405)


@csrf_exempt
def api_prets_en_attente(request):
    try:
        prets = Pret.objects.filter(statut='EN_ATTENTE').order_by('-id')
        data = [{
            'id': p.id,
            'membre': f"{p.membre.nom} {p.membre.prenom}".strip() if p.membre else "Inconnu",
            'membre_id': p.membre_id,
            'montant': float(p.montant),
            'motif': getattr(p, 'motif', ''),
            'statut': p.statut
        } for p in prets]
        return JsonResponse({'success': True, 'data': data})
    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)}, status=400)


@csrf_exempt
def api_valider_demande(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            pret_id = data.get('id')
            approuver = data.get('approuver', False)

            pret = Pret.objects.get(id=pret_id)
            pret.statut = 'APPROUVE' if approuver else 'REJETE'
            pret.save()

            return JsonResponse({'success': True, 'message': 'Demande mise à jour avec succès !'})
        except Pret.DoesNotExist:
            return JsonResponse({'success': False, 'message': 'Prêt introuvable'}, status=404)
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'success': False, 'message': 'Méthode non autorisée'}, status=405)


@csrf_exempt
def api_valider_presence_qr(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            qr_token = data.get('qr_token')
            membre = Membre.objects.filter(id=qr_token).first() if str(qr_token).isdigit() else None
            if membre:
                return JsonResponse({'success': True, 'message': f'Présence validée pour {membre.nom} {membre.prenom}'})
            return JsonResponse({'success': True, 'message': 'Présence enregistrée avec succès !'})
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'success': False, 'message': 'Méthode non autorisée'}, status=405)


@csrf_exempt
def api_rapports(request):
    try:
        total_membres = Membre.objects.count()
        total_prets = Pret.objects.count()
        prets_actifs = Pret.objects.filter(statut__in=['ATTRIBUE', 'APPROUVE']).count()
        data = {
            'total_membres': total_membres,
            'total_prets': total_prets,
            'prets_actifs': prets_actifs,
        }
        return JsonResponse({'success': True, 'data': data})
    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)}, status=400)


@csrf_exempt
def api_credits_en_retard(request):
    try:
        credits = Pret.objects.filter(statut='EN_RETARD') if hasattr(Pret, 'statut') else []
        data = [{
            'id': c.id,
            'membre': f"{c.membre.nom} {c.membre.prenom}".strip() if c.membre else "Inconnu",
            'montant': float(c.montant),
            'statut': getattr(c, 'statut', 'EN_RETARD')
        } for c in credits]
        return JsonResponse({'success': True, 'data': data})
    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)}, status=400)


@csrf_exempt
def api_appliquer_penalite(request, creditId):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            taux = float(data.get('taux_penalite_mensuel', 0))
            pret = Pret.objects.get(id=creditId)
            if hasattr(pret, 'penalite'):
                pret.penalite = float(getattr(pret, 'penalite', 0) or 0) + (float(pret.montant) * taux / 100)
                pret.save()
            return JsonResponse({'success': True, 'message': 'Pénalité appliquée avec succès !'})
        except Pret.DoesNotExist:
            return JsonResponse({'success': False, 'message': 'Crédit introuvable'}, status=404)
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'success': False, 'message': 'Méthode non autorisée'}, status=405)


@csrf_exempt
def api_portefeuille_view(request, membreId):
    try:
        membre = Membre.objects.get(id=membreId)
        is_active = getattr(membre, 'is_active', 1) == 1
        credits_dict = membre.calculer_credits

        data = {
            'nom_complet': f"{membre.nom or ''} {membre.prenom or ''}".strip(),
            'solde_epargne': float(membre.solde_epargne or 0.0),
            'solde_pret': float(membre.solde_pret or 0.0),
            'status_presence': membre.status_presence or 'N/A',
            'statut': 'Actif' if is_active else 'Inactif',
            'groupe_id': membre.groupe_id if membre.groupe_id else 1,
            'caisse_sociale': float(membre.solde_caisse_sociale),
            'total_cotisations_sociales': float(membre.total_cotisation_sociale),
            'total_decaissements_sociaux': float(membre.total_decaissements_social),
            'credit_en_cours': float(credits_dict['en_cours']),
            'credit_rembourse': float(credits_dict['rembourse']),
            'credit_restant': float(credits_dict['restant']),
        }
        return JsonResponse({'success': True, 'data': data})
    except Membre.DoesNotExist:
        return JsonResponse({'success': False, 'message': 'Membre non trouvé'}, status=404)