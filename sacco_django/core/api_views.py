import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth import authenticate, login
from django.contrib.auth.models import User
from .models import Membre, Pret, TransactionHistory, Groupe


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
            role_utilisateur = getattr(membre, 'role', 'MEMBRE')
            if not role_utilisateur or str(role_utilisateur).strip() == '':
                role_utilisateur = 'MEMBRE'

            return JsonResponse({
                'success': True,
                'message': 'Connexion réussie',
                'membre_id': membre.id,
                'user_id': user.id,
                'username': f"{membre.nom} {membre.prenom}".strip(),
                'role': str(role_utilisateur).lower()
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

        credits_dict = membre.calculer_credits

        data = {
            'nom_complet': f"{membre.nom or ''} {membre.prenom or ''}".strip(),
            'solde_epargne': float(membre.solde_epargne or 0.0),
            'statut': 'Actif' if is_active else 'Inactif',
            'groupe_id': membre.groupe_id if membre.groupe_id else 1,
            'nom_groupe': getattr(membre.groupe, 'nom', 'Solidarité') if hasattr(membre,
                                                                                 'groupe') and membre.groupe else 'Solidarité',

            'caisse_sociale_cotisations': float(membre.total_cotisation_sociale),
            'caisse_sociale_decaissements': float(membre.total_decaissements_social),
            'caisse_sociale_nette': float(membre.solde_caisse_sociale),

            'credit_en_cours': float(credits_dict['en_cours']),
            'credit_rembourse': float(credits_dict['rembourse']),
            'credit_restant': float(credits_dict['restant']),
        }
        return JsonResponse({'success': True, 'data': data})
    except Membre.DoesNotExist:
        return JsonResponse({'success': False, 'message': 'Membre non trouvé'}, status=404)


@csrf_exempt
def api_profil_membre(request, membreId):
    try:
        membre = Membre.objects.get(id=membreId)
        groupe = getattr(membre, 'groupe', None)
        nom_groupe = 'Non assigné'
        if groupe:
            for attr in ['nom', 'name', 'libelle', 'titre', 'designation', 'intitule']:
                val = getattr(groupe, attr, None)
                if val and str(val).strip():
                    nom_groupe = str(val).strip()
                    break
            if nom_groupe == 'Non assigné':
                nom_groupe = str(groupe)

        precedente_reunion = 'Non définie'
        for source in [groupe, membre]:
            if source:
                for attr in ['date_reunion_precedente', 'precedente_reunion', 'date_reunion_derniere',
                             'derniere_reunion', 'date_derniere_reunion']:
                    val = getattr(source, attr, None)
                    if val and str(val).strip():
                        precedente_reunion = str(val).strip()
                        break
                if precedente_reunion != 'Non définie':
                    break

        prochaine_reunion = 'À déterminer'
        for source in [groupe, membre]:
            if source:
                for attr in ['date_reunion_prochaine', 'prochaine_reunion', 'date_prochaine_reunion',
                             'prochaine_reunion_date']:
                    val = getattr(source, attr, None)
                    if val and str(val).strip():
                        prochaine_reunion = str(val).strip()
                        break
                if prochaine_reunion != 'À déterminer':
                    break

        assigned_groupe_id = groupe.id if groupe else (getattr(membre, 'groupe_id', None) or 1)

        data = {
            'id': membre.id,
            'nom': membre.nom,
            'prenom': membre.prenom,
            'telephone': membre.telephone,
            'cni': getattr(membre, 'cni', ''),
            'age': getattr(membre, 'age', ''),
            'sexe': getattr(membre, 'sexe', ''),
            'colline': getattr(membre, 'colline', ''),
            'quartier': getattr(membre, 'quartier', ''),
            'avenue': getattr(membre, 'avenue', ''),
            'maison': getattr(membre, 'maison', ''),
            'role': getattr(membre, 'role', 'MEMBRE'),
            'derniere_connexion': str(getattr(membre, 'last_login', 'Première session')),
            'groupe_id': assigned_groupe_id,
            'nom_groupe': nom_groupe,
            'date_reunion_derniere': precedente_reunion,
            'date_reunion_prochaine': prochaine_reunion,

            'groupe': {
                'id': assigned_groupe_id,
                'nom': nom_groupe,
                'date_reunion_derniere': precedente_reunion,
                'date_reunion_prochaine': prochaine_reunion,
                'president': getattr(groupe, 'president', 'N/D') if groupe else 'N/D',
                'secretaire': getattr(groupe, 'secretaire', 'N/D') if groupe else 'N/D',
                'admin_sys': getattr(groupe, 'admin_sys', 'N/D') if groupe else 'N/D',
            }
        }
        return JsonResponse({'success': True, 'data': data})
    except Membre.DoesNotExist:
        return JsonResponse({'success': False, 'message': 'Membre non trouvé'}, status=404)
    except Exception as e:
        print(f"❌ [PROFIL ERREUR] {e}")
        return JsonResponse({'success': False, 'message': str(e)}, status=400)


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
            taux = data.get('taux_interet_applique') or data.get('taux_interet', 5.0)
            duree = data.get('duree_mois', 3)

            pret = Pret.objects.create(
                membre=membre,
                montant=montant,
                motif=motif,
                taux_interet=taux,
                duree_mois=duree,
                statut='EN_ATTENTE'
            )
            return JsonResponse({'success': True, 'message': 'Demande de crédit enregistrée', 'pret_id': pret.id},
                                status=201)
        except Membre.DoesNotExist:
            return JsonResponse({'success': False, 'message': 'Membre introuvable'}, status=404)
        except Exception as e:
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
            taux = data.get('taux_interet', 0.0)
            duree = data.get('duree_mois', 1)

            pret = Pret.objects.create(
                membre=membre,
                montant=montant,
                motif=f"[Social] {raw_motif}",
                taux_interet=taux,
                duree_mois=duree,
                statut='EN_ATTENTE'
            )
            return JsonResponse({'success': True, 'message': 'Demande sociale enregistrée', 'pret_id': pret.id},
                                status=201)
        except Membre.DoesNotExist:
            return JsonResponse({'success': False, 'message': 'Membre introuvable'}, status=404)
        except Exception as e:
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
            'date_demande': p.created_at.strftime('%Y-%m-%d %H:%M:%S') if hasattr(p,
                                                                                  'created_at') and p.created_at else '',
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
            'description': getattr(t, 'description', '') or getattr(t, 'type_operation', ''),
            'date': t.date.strftime('%Y-%m-%d') if hasattr(t, 'date') and t.date else (
                t.created_at.strftime('%Y-%m-%d') if hasattr(t, 'created_at') and t.created_at else ''),
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

            return JsonResponse({'success': True, 'message': 'Inscription réussie !', 'membre_id': membre.id},
                                status=201)
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
        tous_les_prets = Pret.objects.all()
        print(f"🔍 [DIAGNOSTIC PRÊTS] Total de prêts en BDD : {tous_les_prets.count()}")
        for p in tous_les_prets:
            print(f"   - Prêt ID {p.id} | Statut en BDD: '{p.statut}' | Montant: {p.montant}")

        prets = Pret.objects.filter(statut__iexact='EN_ATTENTE').order_by('-id')
        print(f"🔍 [DIAGNOSTIC PRÊTS] Prêts filtrés 'EN_ATTENTE' : {prets.count()}")

        data = [{
            'id': p.id,
            'nom': p.membre.nom if p.membre else "Inconnu",
            'prenom': p.membre.prenom if p.membre else "",
            'membre_id': p.membre_id,
            'montant': float(p.montant),
            'type_pret': "SOCIAL" if "[Social]" in getattr(p, 'motif', '') else "CREDIT",
            'motif': getattr(p, 'motif', ''),
            'date_demande': p.created_at.strftime('%Y-%m-%d %H:%M:%S') if hasattr(p, 'created_at') and p.created_at else '',
            'statut': p.statut
        } for p in prets]
        return JsonResponse({'success': True, 'data': data})
    except Exception as e:
        print(f"❌ [ERREUR PRETS] {str(e)}")
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
        from django.db.models import Sum

        groupe_id = request.GET.get('groupe_id')
        membres = Membre.objects.all()
        prets = Pret.objects.all()

        if groupe_id:
            membres = membres.filter(groupe_id=groupe_id)
            prets = prets.filter(membre__groupe_id=groupe_id)

        total_membres = membres.count()
        total_prets = prets.count()
        prets_actifs = prets.filter(statut__in=['ATTRIBUE', 'APPROUVE']).count()
        total_epargne = 0.0
        if hasattr(Membre, 'solde_epargne'):
            total_epargne = membres.aggregate(sum_epargne=Sum('solde_epargne'))['sum_epargne'] or 0.0
        elif hasattr(Membre, 'epargne'):
            total_epargne = membres.aggregate(sum_epargne=Sum('epargne'))['sum_epargne'] or 0.0

        total_credits_actifs = prets.filter(statut__in=['ATTRIBUE', 'APPROUVE']).aggregate(sum_montant=Sum('montant'))[
                                   'sum_montant'] or 0.0

        total_social = 0.0
        if hasattr(Membre, 'solde_caisse_sociale'):
            total_social = membres.aggregate(sum_social=Sum('solde_caisse_sociale'))['sum_social'] or 0.0

        penalites_percues = 0.0
        if hasattr(Pret, 'penalite'):
            penalites_percues = prets.aggregate(sum_penalite=Sum('penalite'))['sum_penalite'] or 0.0

        data = {
            'total_membres': total_membres,
            'total_prets': total_prets,
            'prets_actifs': prets_actifs,
            'total_epargne': float(total_epargne),
            'total_credits_actifs': float(total_credits_actifs),
            'total_social': float(total_social),
            'penalites_percues': float(penalites_percues),
        }
        return JsonResponse({'success': True, 'data': data})
    except Exception as e:
        print(f"❌ [ERREUR RAPPORTS] {str(e)}")
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
            'nom_groupe': getattr(membre.groupe, 'nom', 'Solidarité') if hasattr(membre,
                                                                                 'groupe') and membre.groupe else 'Solidarité',
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


@csrf_exempt
def api_modifier_calendrier_groupe(request, groupId):
    if request.method == 'PUT' or request.method == 'POST':
        try:
            data = json.loads(request.body)
            nouvelle_date = data.get('date_reunion_prochaine')

            groupe = Groupe.objects.get(id=groupId)
            for attr in ['date_reunion_prochaine', 'prochaine_reunion', 'date_prochaine_reunion']:
                if hasattr(groupe, attr):
                    setattr(groupe, attr, nouvelle_date)
                    break
            groupe.save()

            return JsonResponse({'success': True, 'message': 'Calendrier mis à jour avec succès !'})
        except Groupe.DoesNotExist:
            return JsonResponse({'success': False, 'message': 'Groupe introuvable'}, status=404)
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'success': False, 'message': 'Méthode non autorisée'}, status=405)


@csrf_exempt
def api_groupe_membres_view(request, groupId):
    try:
        membres = Membre.objects.filter(groupe_id=groupId)
        data = [{
            'id': m.id,
            'nom': m.nom,
            'prenom': m.prenom,
            'epargne_defaut': float(getattr(m, 'epargne_defaut', 5000.0)),
            'caisse_defaut': float(getattr(m, 'caisse_defaut', 500.0)),
        } for m in membres]
        return JsonResponse({'success': True, 'data': data})
    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)}, status=400)