import os
import io
import csv
import json
import bcrypt
import hashlib
import re
import urllib3
import requests
from openai import OpenAI
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors
from bs4 import BeautifulSoup
from django.core.cache import cache
from datetime import datetime, timedelta
from decimal import Decimal
from dateutil.relativedelta import relativedelta
from django.conf import settings
from django.contrib import messages
from django.core.management import call_command
from django.contrib.auth import get_user_model, login as django_login, logout, authenticate, update_session_auth_hash
from django.contrib.auth.decorators import login_required, user_passes_test
from django.contrib.auth.forms import PasswordChangeForm
from django.contrib.staticfiles import finders
from django.core.paginator import Paginator
from django.db import transaction, models
from django.db.models import Q, Sum, F, Count, DecimalField
from django.db.models.functions import Coalesce, TruncMonth
from django.http import HttpResponse, JsonResponse
from django.shortcuts import render, redirect, get_object_or_404
from django.template.loader import render_to_string
from django.urls import reverse
from django.utils import timezone
from django.utils.http import url_has_allowed_host_and_scheme
from django.views.decorators.cache import never_cache
from django.views.decorators.csrf import ensure_csrf_cookie
from django.views.decorators.http import require_POST
try:
    from xhtml2pdf import pisa
except ImportError:
    pisa = None

try:
    import openpyxl
    from openpyxl.styles import PatternFill, Font, Alignment
except ImportError:
    openpyxl = None
from .forms import (
    PartnerMemberOnboardingForm, PartnerProfileForm, TransactionForm, EmployeeCreationForm, LoanRequestForm,
    CollaborateurCreationForm, PartnerDepositForm, DecaissementSocialForm
)
from .models import (
    Membres as Membre, Groupes as Groupe, Groupes, HistoriqueEpargne, TransactionHistory, Pret, Partenaire,
    CollaborateurPartenaire, DemandeCredit, TicketSupport, MessageTicket, User, Transaction, MembreForm, Presence,
    DecaissementSocial, JournalLog
)

# ==============================================================================
# UTILITAIRES & CHECKERS
# ==============================================================================
@login_required
def member_profile_view(request):
    membre_id = request.session.get('membre_id')
    membre = None

    if membre_id:
        membre = get_object_or_404(Membre, id=membre_id)
    elif hasattr(request.user, 'membre'):
        membre = request.user.membre

    transactions = []
    prets = []
    derniere_reunion = None
    prochaine_reunion = None
    taux_interet = 10.0
    date_debut = request.GET.get('date_debut')
    date_fin = request.GET.get('date_fin')

    if membre:
        transactions = Transaction.objects.filter(membre=membre).order_by('-date_transaction')

        if date_debut:
            transactions = transactions.filter(date_transaction__gte=date_debut)
        if date_fin:
            transactions = transactions.filter(date_transaction__lte=date_fin)

        if not date_debut and not date_fin:
            transactions = transactions[:10]

        prets = Pret.objects.filter(membre=membre).order_by('-date_demande')

        groupe = membre.groupe
        if groupe:
            if groupe.taux_interet_reunion is not None:
                taux_interet = groupe.taux_interet_reunion

            raw_date = getattr(groupe, 'date_reunion_derniere', None)

            if not raw_date:
                derniere_presence = Presence.objects.filter(
                    membre__groupe=groupe
                ).order_by('-date_reunion').first()
                if derniere_presence:
                    raw_date = derniere_presence.date_reunion

            if raw_date:
                if isinstance(raw_date, str):
                    try:
                        derniere_reunion = datetime.strptime(raw_date, '%Y-%m-%d').date()
                    except ValueError:
                        try:
                            derniere_reunion = datetime.strptime(raw_date, '%d/%m/%Y').date()
                        except ValueError:
                            derniere_reunion = raw_date
                else:
                    derniere_reunion = raw_date

                if hasattr(derniere_reunion, '__add__') and not isinstance(derniere_reunion, str):
                    prochaine_reunion = derniere_reunion + timedelta(days=7)

    conseil_ia = generer_conseil_financier(membre)
    alerte_defaut = verifier_risque_defaut(membre)

    context = {
        'membre': membre,
        'user': request.user,
        'transactions': transactions,
        'prets': prets,
        'derniere_reunion': derniere_reunion,
        'prochaine_reunion': prochaine_reunion,
        'taux_interet': taux_interet,
        'date_debut': date_debut,
        'date_fin': date_fin,
        'conseil_ia': conseil_ia,
        'alerte_defaut': alerte_defaut,
    }

    return render(request, 'core/member_profile.html', context)

def link_callback(uri, rel):
    result = uri
    if uri.startswith(settings.STATIC_URL):
        path = finders.find(uri.replace(settings.STATIC_URL, ""))
        if path:
            if isinstance(path, (list, tuple)):
                path = path[0]
            result = path
    elif uri.startswith(settings.MEDIA_URL):
        result = os.path.join(settings.MEDIA_ROOT, uri.replace(settings.MEDIA_URL, ""))
    return result

# ==============================================================================
# AUTHENTIFICATION & TABLEAUX DE BORD (DASHBOARDS)
# ==============================================================================

def home_view(request):
    if request.user.is_authenticated:
        if hasattr(request.user, 'partenaire') or getattr(request.user, 'is_partner', False):
            return redirect('core:partner_dashboard')
        return redirect('core:dashboard')
    return redirect('core:login')


@never_cache
@ensure_csrf_cookie
def login_view(request):
    next_url = request.POST.get('next') or request.GET.get('next')
    is_ajax = request.headers.get('x-requested-with') == 'XMLHttpRequest' or 'application/json' in request.headers.get(
        'Accept', ''
    )

    def get_redirect_url(default_route, is_admin_route=False):
        if next_url and url_has_allowed_host_and_scheme(
            url=next_url,
            allowed_hosts={request.get_host()},
            require_https=request.is_secure()
        ):
            if '/manager/' in next_url and not is_admin_route:
                return reverse(default_route)
            return next_url
        return reverse(default_route)

    if request.method == 'GET':
        if request.session.get('is_member_authenticated'):
            return redirect(get_redirect_url('core:dashboard', is_admin_route=False))

        if request.user.is_authenticated:
            if check_is_partner(request.user):
                return redirect(get_redirect_url('core:partner_dashboard', is_admin_route=False))
            elif request.user.is_superuser or request.user.is_staff:
                return redirect(get_redirect_url('core:manager_dashboard', is_admin_route=True))
            else:
                return redirect(get_redirect_url('core:dashboard', is_admin_route=False))

        return render(request, 'core/login.html', {'next': next_url})

    if request.method == 'POST':
        if is_ajax and request.content_type == 'application/json':
            try:
                data = json.loads(request.body)
                user_type = data.get('user_type', 'membre')
                identifier = data.get('identifier', '').strip() or data.get('telephone', '').strip()
                secret = data.get('secret', '').strip() or data.get('pin', '').strip()
            except json.JSONDecodeError:
                return JsonResponse({'success': False, 'error': 'Format de requête invalide.'}, status=400)
        else:
            user_type = request.POST.get('user_type', 'membre')
            identifier = request.POST.get('identifier', '').strip() or request.POST.get('telephone', '').strip()
            secret = request.POST.get('secret', '').strip() or request.POST.get('pin', '').strip()

        if user_type == 'membre':
            try:
                membre = Membre.objects.get(telephone=identifier)
                stored_pin = str(membre.pin)
                authenticated = False

                if stored_pin.startswith('$2b$') or stored_pin.startswith('$2a$'):
                    try:
                        if bcrypt.checkpw(secret.encode('utf-8'), stored_pin.encode('utf-8')):
                            authenticated = True
                    except Exception:
                        pass
                elif len(stored_pin) == 64:
                    if hashlib.sha256(secret.encode('utf-8')).hexdigest() == stored_pin:
                        authenticated = True
                else:
                    if stored_pin == secret:
                        authenticated = True

                if authenticated:
                    membre.last_login = timezone.now().strftime("%Y-%m-%d %H:%M:%S")
                    membre.save()
                    UserModel = get_user_model()
                    django_user, created = UserModel.objects.get_or_create(
                        username=f"membre_{membre.telephone}",
                        defaults={
                            'first_name': membre.prenom or '',
                            'last_name': membre.nom or '',
                            'is_active': True
                        }
                    )

                    backend_path = 'django.contrib.auth.backends.ModelBackend'
                    django_login(request, django_user, backend=backend_path)
                    request.session['is_member_authenticated'] = True
                    request.session['user_id'] = django_user.id
                    request.session['user_type'] = 'membre'
                    request.session['membre_id'] = membre.id
                    request.session['membre_nom'] = f"{membre.prenom or ''} {membre.nom}".strip()
                    request.session['role'] = getattr(membre, 'role', 'membre')

                    redirect_url = get_redirect_url('core:dashboard', is_admin_route=False)
                    if is_ajax:
                        return JsonResponse({'success': True, 'redirect_url': redirect_url})
                    return redirect(redirect_url)
                else:
                    error_msg = 'Téléphone ou Code PIN incorrect.'
                    if is_ajax:
                        return JsonResponse({'success': False, 'error': error_msg}, status=401)
                    return render(request, 'core/login.html', {'error_message': error_msg, 'next': next_url})

            except Membre.DoesNotExist:
                error_msg = 'Téléphone ou Code PIN incorrect.'
                if is_ajax:
                    return JsonResponse({'success': False, 'error': error_msg}, status=401)
                return render(request, 'core/login.html', {'error_message': error_msg, 'next': next_url})

        else:
            user = authenticate(request, username=identifier, password=secret)
            if user is not None and user.is_active:
                is_partner_user = check_is_partner(user)
                is_admin = user.is_superuser or user.is_staff

                if user_type == 'partenaire' and (is_partner_user or is_admin):
                    django_login(request, user)
                    request.session['user_id'] = user.id
                    request.session['user_type'] = 'partenaire'
                    request.session['role'] = 'partenaire'

                    redirect_url = get_redirect_url('core:partner_dashboard', is_admin_route=False)
                    if is_ajax:
                        return JsonResponse({'success': True, 'redirect_url': redirect_url})
                    return redirect(redirect_url)

                elif user_type == 'admin' and is_admin:
                    django_login(request, user)
                    request.session['user_id'] = user.id
                    request.session['user_type'] = 'admin'
                    request.session['role'] = 'admin'

                    redirect_url = get_redirect_url('core:manager_dashboard', is_admin_route=True)
                    if is_ajax:
                        return JsonResponse({'success': True, 'redirect_url': redirect_url})
                    return redirect(redirect_url)
                else:
                    error_msg = "Vous n'avez pas les droits pour cet espace."
                    if is_ajax:
                        return JsonResponse({'success': False, 'error': error_msg}, status=403)
                    return render(request, 'core/login.html', {'error_message': error_msg, 'next': next_url})
            else:
                error_msg = "Nom d'utilisateur ou mot de passe incorrect."
                if is_ajax:
                    return JsonResponse({'success': False, 'error': error_msg}, status=401)
                return render(request, 'core/login.html', {'error_message': error_msg, 'next': next_url})


def logout_view(request):
    logout(request)
    request.session.flush()
    messages.info(request, "Vous avez été déconnecté.")
    return redirect('core:login')


def check_is_partner(user):
    if not user or not user.is_authenticated:
        return False
    return (
        user.groups.filter(name='Partenaires').exists() or
        Partenaire.objects.filter(nom=user.username).exists() or
        getattr(user, 'is_partner', False) or
        hasattr(user, 'partenaire')
    )


def partner_login_view(request):
    if request.user.is_authenticated:
        if getattr(request.user, 'is_partner', False) or hasattr(request.user, 'partenaire'):
            return redirect('core:partner_dashboard')
        return redirect('core:dashboard')

    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        user = authenticate(request, username=username, password=password)

        if user is not None:
            if getattr(user, 'is_partner', False) or hasattr(user, 'partenaire'):
                django_login(request, user)
                return redirect('core:partner_dashboard')
            else:
                messages.error(request, "Ce compte ne possède pas les privilèges partenaire.")
        else:
            messages.error(request, "Nom d'utilisateur ou mot de passe incorrect.")

    return render(request, 'core/partner_login.html')


@login_required
def dashboard_view(request):
    user_type = request.session.get('user_type')
    print("================ DIAGNOSTIC DASHBOARD VIEW ================")
    print(f"1. user_type en session : {user_type}")
    print(f"2. role en session : {request.session.get('role')}")
    print(f"3. user authentifié : {request.user.username} (Staff: {request.user.is_staff}, Superuser: {request.user.is_superuser})")

    membre_id = request.session.get('membre_id')
    membre = None
    if membre_id:
        membre = Membre.objects.filter(id=membre_id).first()
    elif hasattr(request.user, 'membre'):
        membre = request.user.membre

    if request.method == 'POST' and 'confirmer_reception_pret_id' in request.POST:
        if membre:
            pret_id = request.POST.get('confirmer_reception_pret_id')
            pret_concerne = Pret.objects.filter(id=pret_id, membre=membre).first()
            if pret_concerne and pret_concerne.statut in ['APPROUVE', 'ATTRIBUE']:
                pret_concerne.statut = 'ATTRIBUE'
                pret_concerne.save()
        return redirect('core:dashboard')

    if user_type == 'membre' or request.session.get('is_member_authenticated'):
        print("-> Branche : Utilisateur identifié comme MEMBRE via session")
        print(f"-> Membre récupéré : {membre}")

        transactions = Transaction.objects.filter(membre=membre).order_by('-date_transaction') if membre else []
        prets_actifs = Pret.objects.filter(membre=membre, est_archive=False) if membre else []
        presences = Presence.objects.filter(membre_id=membre.id).order_by('-date_reunion') if membre else []
        transactions_summary = TransactionHistory.objects.filter(membre=membre).values('type_operation').annotate(
            total=Coalesce(Sum('montant'), 0, output_field=DecimalField())
        ) if membre else []

        chart_labels = [item['type_operation'] for item in transactions_summary]
        chart_data = [float(item['total']) for item in transactions_summary]
        decaissements_membre = DecaissementSocial.objects.filter(membre=membre).order_by('-id') if membre else []
        solde_epargne_val = 0
        total_cotisations_caisse_val = 0
        total_decaissements_val = 0
        caisse_sociale_nette_val = 0
        credit_en_cours_val = 0.0
        credit_rembourse_val = 0.0
        credit_restant_val = 0.0
        historique_remboursements = []

        if membre:
            total_epargne = TransactionHistory.objects.filter(
                membre=membre, type_operation='EPARGNE'
            ).aggregate(total=Sum('montant'))['total'] or Decimal('0')
            total_cotisations_caisse = TransactionHistory.objects.filter(
                membre=membre, type_operation='CAISSE_SOCIALE'
            ).aggregate(total=Sum('montant'))['total'] or Decimal('0')
            total_decaissements = DecaissementSocial.objects.filter(
                membre=membre
            ).aggregate(total=Sum('montant_decaisse'))['total'] or Decimal('0')
            solde_epargne_val = float(total_epargne)
            total_cotisations_caisse_val = float(total_cotisations_caisse)
            total_decaissements_val = float(total_decaissements)
            caisse_sociale_nette_val = float(
                max(Decimal('0'), total_cotisations_caisse - Decimal(str(total_decaissements))))
            prets_attribues = Pret.objects.filter(membre=membre, statut='ATTRIBUE', est_archive=False)
            total_credits_accordes = sum([Decimal(str(p.montant_total_a_rembourser())) for p in prets_attribues])
            total_remboursements = TransactionHistory.objects.filter(
                membre=membre, type_operation__in=['Remboursement Crédit', 'REMBOURSEMENT', 'remboursement']
            ).aggregate(total=Sum('montant'))['total'] or Decimal('0')
            credit_en_cours_val = float(total_credits_accordes)
            credit_rembourse_val = float(total_remboursements)
            credit_restant_val = float(max(Decimal('0'), total_credits_accordes - total_remboursements))
            historique_remboursements = TransactionHistory.objects.filter(
                membre=membre, type_operation__in=['Remboursement Crédit', 'REMBOURSEMENT', 'remboursement']
            ).order_by('-date_transaction')

            print(f"-> [DIAGNOSTIC SOLDE MEMBRE ID {membre.id}]")
            print(f" * Total cotisations caisse : {total_cotisations_caisse}")
            print(f" * Total décaissements : {total_decaissements}")
            print(f" * Caisse sociale nette calculée : {caisse_sociale_nette_val}")

        context = {
            'user': request.user,
            'membre': membre,
            'solde_epargne': solde_epargne_val,
            'total_cotisations_caisse': total_cotisations_caisse_val,
            'total_decaissements': total_decaissements_val,
            'caisse_sociale': caisse_sociale_nette_val,
            'transactions': transactions,
            'prets_actifs': prets_actifs,
            'presences': presences,
            'transactions_summary': transactions_summary,
            'chart_labels_json': json.dumps(chart_labels),
            'chart_data_json': json.dumps(chart_data),
            'brb_rates': get_brb_exchange_rates(),
            'decaissements_membre': decaissements_membre,
            'credit_en_cours': credit_en_cours_val,
            'credit_rembourse': credit_rembourse_val,
            'credit_restant': credit_restant_val,
            'historique_remboursements': historique_remboursements,
        }
        return render(request, 'core/dashboard.html', context)

    role = str(request.session.get('role', '')).lower()
    print(f"-> Évaluation des rôles de redirection : role={role}, is_partner={check_is_partner(request.user)}")

    if check_is_partner(request.user) or role == 'partenaire':
        print("-> Redirection vers partner_dashboard")
        return redirect('core:partner_dashboard')
    elif request.user.is_staff or request.user.is_superuser or role in ['admin', 'gestionnaire']:
        print("-> Redirection vers manager_dashboard")
        return redirect('core:manager_dashboard')

    print("-> Branche : Cas par défaut du dashboard_view")
    print(f"-> Membre récupéré par défaut : {membre}")

    transactions = Transaction.objects.filter(membre=membre).order_by('-date_transaction') if membre else []
    prets_actifs = Pret.objects.filter(membre=membre, est_archive=False) if membre else []
    presences = Presence.objects.filter(membre_id=membre.id).order_by('-date_reunion') if membre else []
    transactions_summary = TransactionHistory.objects.filter(membre=membre).values('type_operation').annotate(
        total=Coalesce(Sum('montant'), 0, output_field=DecimalField())
    ) if membre else []
    chart_labels = [item['type_operation'] for item in transactions_summary]
    chart_data = [float(item['total']) for item in transactions_summary]
    decaissements_membre = DecaissementSocial.objects.filter(membre=membre).order_by('-id') if membre else []
    solde_epargne_val = 0
    total_cotisations_caisse_val = 0
    total_decaissements_val = 0
    caisse_sociale_nette_val = 0
    credit_en_cours_val = 0.0
    credit_rembourse_val = 0.0
    credit_restant_val = 0.0
    historique_remboursements = []

    if membre:
        total_epargne = TransactionHistory.objects.filter(
            membre=membre, type_operation='EPARGNE'
        ).aggregate(total=Sum('montant'))['total'] or Decimal('0')
        total_cotisations_caisse = TransactionHistory.objects.filter(
            membre=membre, type_operation='CAISSE_SOCIALE'
        ).aggregate(total=Sum('montant'))['total'] or Decimal('0')
        total_decaissements = DecaissementSocial.objects.filter(
            membre=membre
        ).aggregate(total=Sum('montant_decaisse'))['total'] or Decimal('0')
        solde_epargne_val = float(total_epargne)
        total_cotisations_caisse_val = float(total_cotisations_caisse)
        total_decaissements_val = float(total_decaissements)
        caisse_sociale_nette_val = float(
            max(Decimal('0'), total_cotisations_caisse - Decimal(str(total_decaissements))))
        prets_attribues = Pret.objects.filter(membre=membre, statut='ATTRIBUE', est_archive=False)
        total_credits_accordes = sum([Decimal(str(p.montant_total_a_rembourser())) for p in prets_attribues])
        total_remboursements = TransactionHistory.objects.filter(
            membre=membre, type_operation__in=['Remboursement Crédit', 'REMBOURSEMENT', 'remboursement']
        ).aggregate(total=Sum('montant'))['total'] or Decimal('0')
        credit_en_cours_val = float(total_credits_accordes)
        credit_rembourse_val = float(total_remboursements)
        credit_restant_val = float(max(Decimal('0'), total_credits_accordes - total_remboursements))
        historique_remboursements = TransactionHistory.objects.filter(
            membre=membre, type_operation__in=['Remboursement Crédit', 'REMBOURSEMENT', 'remboursement']
        ).order_by('-date_transaction')

    print(f"-> [DIAGNOSTIC SOLDE DÉFAUT ID {getattr(membre, 'id', 'N/A')}] Caisse nette : {caisse_sociale_nette_val}")

    context = {
        'user': request.user,
        'membre': membre,
        'solde_epargne': solde_epargne_val,
        'total_cotisations_caisse': total_cotisations_caisse_val,
        'total_decaissements': total_decaissements_val,
        'caisse_sociale': caisse_sociale_nette_val,
        'transactions': transactions,
        'prets_actifs': prets_actifs,
        'presences': presences,
        'transactions_summary': transactions_summary,
        'chart_labels_json': json.dumps(chart_labels),
        'chart_data_json': json.dumps(chart_data),
        'brb_rates': get_brb_exchange_rates(),
        'decaissements_membre': decaissements_membre,
        'credit_en_cours': credit_en_cours_val,
        'credit_rembourse': credit_rembourse_val,
        'credit_restant': credit_restant_val,
        'historique_remboursements': historique_remboursements,
    }
    return render(request, 'core/dashboard.html', context)


@login_required
def manager_dashboard_view(request):
    selected_gid = request.GET.get('selected_gid') or request.GET.get('gid') or request.POST.get(
        'gid') or request.POST.get('selected_gid')
    active_tab = request.GET.get('tab', 'caisse_sociale')
    search_query = request.GET.get('q', '').strip()
    tous_les_groupes = Groupe.objects.filter(est_archive=False)
    groupes_all = Groupe.objects.all()
    selected_groupe_param = request.GET.get('groupe')

    groupe_selectionne = None
    if selected_groupe_param:
        groupe_selectionne = groupes_all.filter(pk=selected_groupe_param).first()
        selected_gid = selected_groupe_param
    elif selected_gid:
        groupe_selectionne = tous_les_groupes.filter(pk=selected_gid).first()

    if not groupe_selectionne:
        groupe_selectionne = tous_les_groupes.first()
        selected_gid = groupe_selectionne.id if groupe_selectionne else None

    form = DecaissementSocialForm(request.POST or None, groupe=groupe_selectionne)

    if request.method == 'POST':
        if 'update_all_roles' in request.POST or 'update_role' in request.POST:
            membre_ids = request.POST.getlist('membre_ids')
            for m_id in membre_ids:
                nouveau_role = request.POST.get(f'role_{m_id}')
                if nouveau_role:
                    Membre.objects.filter(pk=m_id).update(role=nouveau_role)

            gid_val = groupe_selectionne.id if groupe_selectionne else ''
            return redirect(f'/manager/?tab=groupes&selected_gid={gid_val}')

        elif 'membre' in request.POST and 'montant_decaisse' in request.POST:
            if form.is_valid():
                decaissement = form.save(commit=False)
                if groupe_selectionne:
                    decaissement.groupe_id = groupe_selectionne.id

                decaissement.date_decaissement = timezone.now().strftime('%d/%m/%Y %H:%M')
                decaissement.save()

                membre_beneficiaire = decaissement.membre
                if membre_beneficiaire:
                    try:
                        montant_val = Decimal(str(decaissement.montant_decaisse or 0).replace(',', '.'))
                        Membre.objects.filter(pk=membre_beneficiaire.pk).update(
                            caisse_sociale=F('caisse_sociale') - montant_val
                        )

                        try:
                            HistoriqueEpargne.objects.create(
                                membre=membre_beneficiaire,
                                date_reunion=timezone.now().date(),
                                caisse_sociale=-montant_val
                            )
                        except Exception:
                            pass

                        TransactionHistory.objects.create(
                            membre=membre_beneficiaire,
                            type_operation='DECAISSEMENT_SOCIAL',
                            montant=montant_val,
                            date_transaction=timezone.now()
                        )
                    except Exception:
                        pass

            gid = request.POST.get('selected_gid') or request.POST.get('gid') or (
                groupe_selectionne.id if groupe_selectionne else '')

            url = reverse('core:manager_dashboard')
            if gid:
                return redirect(f"{url}?tab=caisse_sociale&selected_gid={gid}")
            return redirect(f"{url}?tab=caisse_sociale")

    groupes_archives = Groupe.objects.filter(est_archive=True)
    tous_les_membres = Membre.objects.all()
    membres = tous_les_membres.select_related('groupe').order_by('-id')
    if selected_groupe_param:
        membres = membres.filter(groupe_id=selected_groupe_param)
    elif search_query and active_tab != 'caisse_sociale':
        membres = membres.filter(
            Q(nom__icontains=search_query) | Q(prenom__icontains=search_query) |
            Q(telephone__icontains=search_query)
        )

    total_epargne = tous_les_membres.aggregate(total=Sum('solde_epargne'))['total'] or Decimal('0')
    total_caisse_sociale = tous_les_membres.aggregate(total=Sum('caisse_sociale'))['total'] or Decimal('0')
    total_credits = tous_les_membres.aggregate(total=Sum('credit_en_cours'))['total'] or Decimal('0')
    total_credits_traitement = Pret.objects.filter(
        statut__in=['EN_ATTENTE', 'SOUMIS', 'EN_COURS_DE_TRAITEMENT', 'En attente']
    ).aggregate(total=Sum('montant'))['total'] or Decimal('0')
    total_groupes_actifs = tous_les_groupes.count()
    top_membres = tous_les_membres.order_by('-solde_epargne')[:10000]
    noms_membres_list = [f"{m.prenom} {m.nom}".strip() for m in top_membres]
    soldes_epargne_list = [float(m.solde_epargne or 0) for m in top_membres]
    journal_logs_recents = JournalLog.objects.all().order_by('-date_action')[:10]
    paginator = Paginator(membres, 20)
    page_number = request.GET.get('page')
    membres_page = paginator.get_page(page_number)
    membres_groupe = Membre.objects.filter(groupe=groupe_selectionne) if groupe_selectionne else Membre.objects.none()

    role_query = request.GET.get('role_q', '').strip()
    membres_pour_role = membres_groupe
    if role_query and membres_groupe:
        membres_pour_role = membres_groupe.filter(
            Q(nom__icontains=role_query) | Q(prenom__icontains=role_query) |
            Q(telephone__icontains=role_query)
        )

    tous_les_partenaires = Partenaire.objects.all()
    selected_type = request.GET.get('type_op', '')

    transactions_list = TransactionHistory.objects.all().order_by('-date_transaction')
    transactions_qs = transactions_list

    if selected_type:
        transactions_qs = transactions_qs.filter(type_operation=selected_type)

    if search_query and active_tab == 'transactions':
        transactions_qs = transactions_qs.filter(
            Q(membre__nom__icontains=search_query) | Q(membre__prenom__icontains=search_query) |
            Q(membre__telephone__icontains=search_query) | Q(description__icontains=search_query)
        )

    paginator_tx = Paginator(transactions_qs, 20)
    tx_page_number = request.GET.get('page') if active_tab == 'transactions' else None
    transactions_page = paginator_tx.get_page(tx_page_number)

    total_depots = TransactionHistory.objects.filter(
        Q(type_operation__iexact='DEPOT') | Q(type_operation__iexact='Dépôt')
    ).aggregate(total=Sum('montant'))['total'] or Decimal('0')

    total_retraits = TransactionHistory.objects.filter(
        Q(type_operation__iexact='RETRAIT') | Q(type_operation__iexact='Retrait')
    ).aggregate(total=Sum('montant'))['total'] or Decimal('0')

    total_penalites = TransactionHistory.objects.filter(
        Q(type_operation__iexact='PENALITE') | Q(type_operation__iexact='Pénalité') |
        Q(type_operation__iexact='AMENDE') | Q(type_operation__iexact='Amende')
    ).aggregate(total=Sum('montant'))['total'] or Decimal('0')

    total_credits_octroyes = TransactionHistory.objects.filter(
        Q(type_operation__icontains='CREDIT') | Q(type_operation__icontains='Crédit')
    ).aggregate(total=Sum('montant'))['total'] or Decimal('0')

    if groupe_selectionne:
        decaissements = DecaissementSocial.objects.filter(
            Q(groupe_id=groupe_selectionne.id) | Q(membre__groupe=groupe_selectionne)
        ).distinct().order_by('-id')

        total_decaisse_groupe = sum([
            Decimal(str(d.montant_decaisse or 0).replace(',', '.'))
            for d in decaissements
        ]) or Decimal('0')

        membres_du_groupe = Membre.objects.filter(groupe=groupe_selectionne)
        solde_disponible_caisse = sum([
            Decimal(str(m.caisse_sociale or 0).replace(',', '.'))
            for m in membres_du_groupe
        ]) or Decimal('0')

        total_cotisations_caisse = solde_disponible_caisse + total_decaisse_groupe
    else:
        decaissements = DecaissementSocial.objects.none()
        total_cotisations_caisse = Decimal('0')
        total_decaisse_groupe = Decimal('0')
        solde_disponible_caisse = Decimal('0')

    pivot_sociale = []
    dates_reunions = []
    totaux_caisse_sociale_par_date = []
    total_report_anterieur = Decimal('0')
    grand_total_caisse_sociale = Decimal('0')

    if groupe_selectionne:
        membres_groupe_social = Membre.objects.filter(groupe=groupe_selectionne)

        transactions_sociales = TransactionHistory.objects.filter(
            membre__in=membres_groupe_social,
            type_operation='CAISSE_SOCIALE'
        ).order_by('date_transaction')

        dates_set = sorted(list(set(
            t.date_transaction.strftime('%d/%m/%Y') for t in transactions_sociales if t.date_transaction
        )))
        dates_reunions = dates_set

        for m in membres_groupe_social:
            m_transactions = transactions_sociales.filter(membre=m)

            montants_par_date = {}
            for t in m_transactions:
                if t.date_transaction:
                    d_str = t.date_transaction.strftime('%d/%m/%Y')
                    montants_par_date[d_str] = montants_par_date.get(d_str, Decimal('0')) + Decimal(str(t.montant or 0))

            ligne_montants = []
            total_membre = Decimal('0')
            for d in dates_reunions:
                montant = montants_par_date.get(d, Decimal('0'))
                ligne_montants.append(montant)
                total_membre += montant

            report_anterieur = Decimal('0')
            total_cumul = report_anterieur + total_membre
            grand_total_caisse_sociale += total_cumul
            total_report_anterieur += report_anterieur

            pivot_sociale.append({
                'membre_id': m.id,
                'nom_complet': f"{m.prenom or ''} {m.nom or ''}".strip(),
                'report_anterieur': report_anterieur,
                'montants': ligne_montants,
                'total_cumul': total_cumul
            })

        totaux_caisse_sociale_par_date = []
        for i, d in enumerate(dates_reunions):
            col_total = sum(ligne['montants'][i] for ligne in pivot_sociale if len(ligne['montants']) > i)
            totaux_caisse_sociale_par_date.append(col_total)

    table_epargne = []
    totaux_par_colonne = []
    total_general_caisse_sociale = Decimal('0')
    grand_total_general = Decimal('0')

    if groupe_selectionne:
        membres_groupe_epargne = Membre.objects.filter(groupe=groupe_selectionne)

        transactions_epargne = TransactionHistory.objects.filter(
            membre__in=membres_groupe_epargne,
            type_operation__iexact='EPARGNE'
        ).order_by('date_transaction')

        if not dates_reunions:
            dates_reunions = sorted(list(set(
                t.date_transaction.strftime('%d/%m/%Y') for t in transactions_epargne if t.date_transaction
            )))

        sommes_colonnes = [Decimal('0')] * len(dates_reunions)

        for m in membres_groupe_epargne:
            m_txs = transactions_epargne.filter(membre=m)
            montants_Dict = {}
            for t in m_txs:
                if t.date_transaction:
                    d_str = t.date_transaction.strftime('%d/%m/%Y')
                    montants_Dict[d_str] = montants_Dict.get(d_str, Decimal('0')) + Decimal(str(t.montant or 0))

            details_ligne = []
            cumul_membre = Decimal('0')
            for idx, d in enumerate(dates_reunions):
                val = montants_Dict.get(d, Decimal('0'))
                cumul_membre += val
                sommes_colonnes[idx] += val
                details_ligne.append(f"{val:,.0f} / {cumul_membre:,.0f}".replace(',', ' '))

            caisse_soc = Decimal(str(m.caisse_sociale or 0))
            solde_total = cumul_membre + caisse_soc
            total_general_caisse_sociale += caisse_soc
            grand_total_general += solde_total

            table_epargne.append({
                'id': m.id,
                'nom_complet': f"{m.prenom or ''} {m.nom or ''}".strip(),
                'details': details_ligne,
                'caisse_sociale': caisse_soc,
                'solde_total_avec_sociale': solde_total
            })

        totaux_par_colonne = sommes_colonnes

    context = {
        'admin_nom': request.user.username,
        'search_query': search_query,
        'role_query': role_query,
        'selected_gid': selected_gid,
        'active_tab': active_tab,
        'total_membres': tous_les_membres.count(),
        'total_groupes': tous_les_groupes.count(),
        'total_groupes_actifs': total_groupes_actifs,
        'total_epargne': total_epargne,
        'total_caisse_sociale': total_caisse_sociale,
        'total_credits': total_credits_octroyes,
        'total_credits_traitement': total_credits_traitement,
        'membres': membres_page,
        'groupes': groupes_all,
        'selected_groupe': selected_groupe_param,
        'tous_les_groupes': tous_les_groupes,
        'groupe_selectionne': groupe_selectionne,
        'groupe': groupe_selectionne,
        'membres_groupe': membres_groupe,
        'membres_pour_role': membres_pour_role,
        'groupes_archives': groupes_archives,
        'tous_les_partenaires': tous_les_partenaires,
        'total_depots': total_depots,
        'total_retraits': total_retraits,
        'total_penalites': total_penalites,
        'selected_type': selected_type,
        'transactions': transactions_page,
        'transactions_list': transactions_list,
        'noms_membres': json.dumps(noms_membres_list),
        'soldes_epargne': json.dumps(soldes_epargne_list),
        'pivot_sociale': pivot_sociale,
        'dates_reunions': dates_reunions,
        'totaux_caisse_sociale_par_date': totaux_caisse_sociale_par_date,
        'total_report_anterieur': total_report_anterieur,
        'grand_total_caisse_sociale': grand_total_caisse_sociale,
        'form': form,
        'decaissements': decaissements,
        'total_caisse_groupe': total_cotisations_caisse,
        'total_decaisse': total_decaisse_groupe,
        'solde_disponible': solde_disponible_caisse,
        'brb_rates': get_brb_exchange_rates(),
        'table_epargne': table_epargne,
        'totaux_par_colonne': totaux_par_colonne,
        'total_general_caisse_sociale': total_general_caisse_sociale,
        'grand_total_general': grand_total_general,
        'tous_les_membres': tous_les_membres,
        'journal_logs_recents': journal_logs_recents,
    }

    return render(request, 'core/manager_dashboard.html', context)


@login_required(login_url='core:partner_login')
@user_passes_test(check_is_partner, login_url='core:partner_login')
def partner_dashboard_view(request):
    user = request.user
    now = timezone.now()
    partenaire_obj = Partenaire.objects.filter(nom=user.username).first()

    if partenaire_obj:
        groupes_qs = Groupe.objects.filter(partenaire=partenaire_obj)
        groupe_selectionne = groupes_qs.first()
        membres_qs = Membre.objects.filter(groupe__partenaire=partenaire_obj)
        transactions_qs = TransactionHistory.objects.filter(membre__groupe__partenaire=partenaire_obj)
        groupes_ids = membres_qs.values_list('groupe_id', flat=True).distinct()
        presences_qs = Presence.objects.filter(groupe_id__in=groupes_ids).order_by('-date_reunion')
        prets_en_cours = Pret.objects.filter(
            membre__groupe__partenaire=partenaire_obj,
            est_archive=False,
            statut__in=['EN_ATTENTE', 'APPROUVE', 'EN_ATTENTE_AGENT', 'EN_ATTENTE_DIRECTEUR']
        ).order_by('-date_demande')
        credits_verses = Pret.objects.filter(
            membre__groupe__partenaire=partenaire_obj,
            statut__in=['ATTRIBUE', 'attribue', 'APPROUVE', 'approuve'],
            est_archive=False
        ).order_by('-date_demande')
    else:
        groupes_qs = Groupe.objects.none()
        groupe_selectionne = None
        membres_qs = Membre.objects.none()
        transactions_qs = TransactionHistory.objects.none()
        presences_qs = Presence.objects.none()
        prets_en_cours = Pret.objects.none()
        credits_verses = Pret.objects.none()

    total_membres = membres_qs.count()
    fonds_geres = membres_qs.aggregate(
        total=Sum('solde_epargne')
    )['total'] or 0.00

    commissions_mois = 0.00
    transactions_recentes = transactions_qs.order_by('-date_transaction')[:5]
    donnees_graphique = []
    labels_graphique = []
    for i in range(5, -1, -1):
        mois_cible = now - timedelta(days=30 * i)
        mensuel = transactions_qs.filter(
            date_transaction__year=mois_cible.year,
            date_transaction__month=mois_cible.month
        ).aggregate(total=Sum('montant'))['total'] or 0

        labels_graphique.append(mois_cible.strftime("%b %Y"))
        donnees_graphique.append(float(mensuel))

    dossiers_scoring_ia = []
    for pret in prets_en_cours:
        if pret.membre:
            score_data = calculer_credit_scoring(pret.membre, pret)
            dossiers_scoring_ia.append(score_data)

    alertes_anomalies = detecter_anomalies_financieres(partenaire_obj)

    context = {
        'is_partner': True,
        'partner_name': user.username,
        'groupes': groupes_qs,
        'groupe_selectionne': groupe_selectionne,
        'membres_qs': membres_qs,
        'total_membres': total_membres,
        'fonds_geres': fonds_geres,
        'commissions_mois': commissions_mois,
        'transactions_recentes': transactions_recentes,
        'presences': presences_qs,
        'labels_graphique': labels_graphique,
        'donnees_graphique': donnees_graphique,
        'brb_rates': get_brb_exchange_rates(),
        'dossiers_scoring_ia': dossiers_scoring_ia,
        'credits_verses': credits_verses,
        'alertes_anomalies': alertes_anomalies,
    }

    return render(request, 'core/partner_dashboard.html', context)


def get_brb_exchange_rates():
    cached_rates = cache.get('brb_rates_cache')
    if cached_rates:
        return cached_rates

    rates = {
        'USD': 'N/A', 'usd': 'N/A',
        'EUR': 'N/A', 'eur': 'N/A'
    }

    try:
        url = "https://www.brb.bi/Details%20Taux%20de%20Change"
        headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        }
        response = requests.get(url, headers=headers, timeout=10, verify=False)

        if response.status_code == 200:
            soup = BeautifulSoup(response.text, 'html.parser')
            rows = soup.find_all('tr')

            for row in rows:
                cols = row.find_all(['td', 'th'])
                if len(cols) >= 2:
                    row_text = row.get_text().upper()

                    if 'USD' in row_text and rates['USD'] == 'N/A':
                        val = cols[-1].get_text(strip=True) or cols[1].get_text(strip=True)
                        val_clean = re.sub(r'[^\d.,]', '', val)
                        if val_clean:
                            rates['USD'] = val_clean
                            rates['usd'] = val_clean

                    if 'EUR' in row_text and rates['EUR'] == 'N/A':
                        val = cols[-1].get_text(strip=True) or cols[1].get_text(strip=True)
                        val_clean = re.sub(r'[^\d.,]', '', val)
                        if val_clean:
                            rates['EUR'] = val_clean
                            rates['eur'] = val_clean

                    if rates['USD'] != 'N/A' and rates['EUR'] != 'N/A':
                        break

        if rates['USD'] != 'N/A' or rates['EUR'] != 'N/A':
            cache.set('brb_rates_cache', rates, 7200)

    except Exception as e:
        print(f"Erreur lors de la récupération des taux BRB : {e}")

    if rates['USD'] == 'N/A':
        rates['USD'] = rates['usd'] = '2 850 BIF'
    if rates['EUR'] == 'N/A':
        rates['EUR'] = rates['eur'] = '3 100 BIF'

    return rates

# ==============================================================================
# GESTION DES MEMBRES & GROUPES
# ==============================================================================

@login_required
def ajouter_membre_view(request):
    if request.method == 'POST':
        form = MembreForm(request.POST)
        if form.is_valid():
            form.save()
            messages.success(request, "Membre enregistré avec succès.")
            return redirect('core:manager_dashboard')
        else:
            messages.error(request, "Veuillez corriger les erreurs dans le formulaire.")
    else:
        form = MembreForm()

    return render(request, 'core/add_member.html', {'form': form})


# ==============================================================================
# SAISIES FINANCIÈRES & TRANSACTIONS
# ==============================================================================

def add_transaction_view(request, membre_id):
    membre = get_object_or_404(Membre, id=membre_id)

    if request.method == 'POST':
        montant = request.POST.get('montant')
        type_transaction = request.POST.get('type_transaction', 'epargne')

        if montant:
            try:
                valeur = float(montant)
                if type_transaction == 'epargne':
                    membre.solde_epargne = (membre.solde_epargne or 0) + valeur
                elif type_transaction == 'sociale':
                    membre.caisse_sociale = (membre.caisse_sociale or 0) + valeur

                membre.save()
                HistoriqueEpargne.objects.create(
                    membre=membre,
                    groupe_id=getattr(membre, 'groupe_id', None),
                    montant_epargne=valeur if type_transaction == 'epargne' else 0,
                    montant_social=valeur if type_transaction == 'sociale' else 0,
                    enregistre_par=request.user.username if request.user.is_authenticated else "Admin"
                )

                messages.success(request, "Transaction enregistrée avec succès.")
            except ValueError:
                messages.error(request, "Montant invalide.")

        return redirect('core:manager_dashboard')

    return render(request, 'core/add_transaction.html', {'membre': membre})


def filtered_transactions_view(request):
    search_query = request.GET.get('q', '').strip()
    selected_type = request.GET.get('type_op', '') or request.GET.get('type', '')
    date_debut = request.GET.get('date_debut', '')
    date_fin = request.GET.get('date_fin', '')
    transactions = TransactionHistory.objects.all().order_by('-date_transaction')

    if search_query:
        transactions = transactions.filter(
            Q(membre__nom__icontains=search_query) |
            Q(membre__prenom__icontains=search_query) |
            Q(reference__icontains=search_query)
        )

    if selected_type:
        transactions = transactions.filter(type_operation=selected_type)

    if date_debut:
        transactions = transactions.filter(date_transaction__gte=date_debut)
    if date_fin:
        transactions = transactions.filter(date_transaction__lte=date_fin)

    if request.headers.get('x-requested-with') == 'XMLHttpRequest':
        html = render_to_string('core/partials/transactions_table.html', {'transactions': transactions}, request=request)
        return HttpResponse(html)

    context = {
        'transactions': transactions,
        'search_query': search_query,
        'selected_type': selected_type,
    }
    return render(request, 'core/filtered_transactions.html', context)


@login_required
@require_POST
def saisie_hebdomadaire_view(request):
    print("=== DEBUT SAISIE HEBDOMADAIRE ===")
    print("CONTENU DE REQUEST.POST :", request.POST.dict())

    role = str(request.session.get('role', '')).lower()
    if 'admin' not in role and 'gestionnaire' not in role and not request.user.is_authenticated:
        return redirect('core:login')

    date_reunion_saisie = request.POST.get('date_reunion') or request.POST.get('date_réunion')
    groupe_id = request.POST.get('groupe_id')
    date_finale = timezone.now().date()

    if date_reunion_saisie:
        try:
            date_finale = datetime.strptime(date_reunion_saisie, '%m/%d/%Y').date()
        except ValueError:
            try:
                date_finale = datetime.strptime(date_reunion_saisie, '%Y-%m-%d').date()
            except ValueError:
                pass

    membre_ids = list(set(
        key.split('_')[-1] for key in request.POST.keys()
        if key.startswith('epargne_') or key.startswith('presence_') or key.startswith(
            'caisse_sociale_') or key.startswith('amende_') or key.startswith('remboursement_')
    ))

    print("IDs de membres extraits :", membre_ids)

    if not membre_ids:
        messages.error(request, "Aucune donnée envoyée.")
        return redirect(request.META.get('HTTP_REFERER', 'core:manager_dashboard'))

    count_updated = 0
    heure_actuelle = datetime.now().strftime("%H:%M:%S")

    try:
        with transaction.atomic():
            for m_id in membre_ids:
                presence_val = request.POST.get(f'presence_{m_id}') or 'P'
                epargne_val = request.POST.get(f'epargne_{m_id}', 0)
                caisse_val = request.POST.get(f'caisse_sociale_{m_id}', 0)
                amende_val = request.POST.get(f'amende_{m_id}', 0)
                remboursement_val = request.POST.get(f'remboursement_{m_id}', 0)

                print(
                    f"Traitement Membre ID {m_id} -> Epargne: {epargne_val}, Caisse: {caisse_val}, Amende: {amende_val}, Remboursement: {remboursement_val}")

                try:
                    epargne = float(epargne_val) if epargne_val else 0.0
                    caisse = float(caisse_val) if caisse_val else 0.0
                    amende = float(amende_val) if amende_val else 0.0
                    remboursement = float(remboursement_val) if remboursement_val else 0.0
                except ValueError:
                    epargne, caisse, amende, remboursement = 0.0, 0.0, 0.0, 0.0

                try:
                    membre = Membre.objects.get(id=m_id)
                    print(f"-> Membre trouvé en BD : {membre}")
                    membre.solde_epargne = (membre.solde_epargne or 0) + epargne
                    membre.caisse_sociale = (membre.caisse_sociale or 0) + caisse
                    membre.status_presence = presence_val
                    membre.save()

                    if presence_val:
                        Presence.objects.update_or_create(
                            membre_id=m_id,
                            date_reunion=date_finale,
                            defaults={'status': presence_val}
                        )

                    HistoriqueEpargne.objects.create(
                        membre=membre,
                        groupe_id=groupe_id if groupe_id else getattr(membre, 'groupe_id', None),
                        montant_epargne=epargne,
                        epargne=epargne,
                        montant_social=caisse,
                        caisse_sociale=caisse,
                        date_reunion=str(date_finale),
                        heure_enregistrement=heure_actuelle,
                        enregistre_par=request.user.username if request.user.is_authenticated else "Admin"
                    )

                    if epargne > 0:
                        Transaction.objects.create(
                            membre=membre,
                            type_operation='EPARGNE',
                            montant=epargne,
                            date_transaction=date_finale
                        )

                    if caisse > 0:
                        Transaction.objects.create(
                            membre=membre,
                            type_operation='CAISSE_SOCIALE',
                            montant=caisse,
                            date_transaction=date_finale
                        )

                    if amende > 0:
                        Transaction.objects.create(
                            membre=membre,
                            type_operation='AMENDE',
                            montant=amende,
                            date_transaction=date_finale
                        )

                    if remboursement > 0:
                        Transaction.objects.create(
                            membre=membre,
                            type_operation='Remboursement Crédit',
                            montant=remboursement,
                            date_transaction=date_finale,
                            description="Remboursement de crédit enregistré lors de la saisie hebdomadaire."
                        )

                    count_updated += 1
                except Membre.DoesNotExist:
                    print(f"❌ ERREUR : Aucun membre trouvé avec l'ID {m_id} en base !")
                    continue

            if groupe_id:
                try:
                    groupe_obj = Groupe.objects.get(id=groupe_id)
                    date_str = str(date_finale)
                    if hasattr(groupe_obj, 'date_reunion_derniere'):
                        groupe_obj.date_reunion_derniere = date_str
                    if hasattr(groupe_obj, 'date_reunion_prochaine'):
                        groupe_obj.date_reunion_prochaine = date_str
                    groupe_obj.save()
                except Groupe.DoesNotExist:
                    pass

        messages.success(request, f"Saisie enregistrée avec succès pour {count_updated} membre(s).")
    except Exception as e:
        print(f"❌ EXCEPTION GLOBALE : {str(e)}")
        messages.error(request, f"Erreur lors de la sauvegarde : {str(e)}")

    return redirect(request.META.get('HTTP_REFERER', 'core:manager_dashboard'))

# ==============================================================================
# PRÊTS ET CRÉDITS
# ==============================================================================

def list_loans_view(request):
    is_ajax = request.headers.get('x-requested-with') == 'XMLHttpRequest' or 'application/json' in request.headers.get('Accept', '')

    if request.user.is_superuser or request.user.is_staff or (hasattr(request.user, 'role') and request.user.role == 'admin'):
        prets = Pret.objects.all().order_by('-id')
    elif hasattr(request.user, 'membre_id') or request.session.get('is_member_authenticated'):
        membre_id = request.session.get('membre_id') or getattr(request.user, 'id', None)
        prets = Pret.objects.filter(membre_id=membre_id).order_by('-id')
    else:
        prets = Pret.objects.none()

    if is_ajax:
        data = []
        for p in prets:
            data.append({
                "id": p.id,
                "montant": getattr(p, 'montant', getattr(p, 'montant_demande', 0)),
                "motif": getattr(p, 'motif', ''),
                "statut": getattr(p, 'statut', 'EN_ATTENTE'),
                "date": p.created_at.strftime('%Y-%m-%d %H:%M:%S') if hasattr(p, 'created_at') and p.created_at else str(datetime.now())
            })
        return JsonResponse({"status": "success", "data": data})

    paginator = Paginator(prets, 10)  # 10 prêts par page
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)

    context = {
        'prets': page_obj,
        'page_obj': page_obj,
    }
    return render(request, 'core/loan_history.html', context)


@login_required
def prets_statistiques_view(request):
    user = request.user
    partenaire_obj = Partenaire.objects.filter(nom=user.username).first()

    from core.models import Groupe
    groupes = Groupe.objects.filter(partenaire=partenaire_obj) if partenaire_obj else Groupe.objects.all()

    if partenaire_obj:
        prets_query = Pret.objects.filter(membre__groupe__partenaire=partenaire_obj)
    else:
        prets_query = Pret.objects.all()

    aujourdhui = timezone.now().date()
    premier_jour_mois_actuel = aujourdhui.replace(day=1)
    debut_periode = premier_jour_mois_actuel - relativedelta(months=2)
    prets_query = prets_query.filter(date_demande__date__gte=debut_periode)
    groupe_id = request.GET.get('groupe')
    if groupe_id:
        prets_query = prets_query.filter(membre__groupe_id=groupe_id)

    stats_mensuelles = (
        prets_query
        .annotate(mois=TruncMonth('date_demande'))
        .values('mois')
        .annotate(
            total_montant=Sum('montant'),
            nombre_prets=Count('id')
        )
        .order_by('mois')
    )

    donnees_mois = []
    labels_graphique = []
    montants_graphique = []
    montant_precedent = None

    for entry in stats_mensuelles:
        mois_dt = entry['mois']
        if mois_dt:
            mois_nom = mois_dt.strftime('%b %Y')
            total = float(entry['total_montant'] or 0)
            nb = entry['nombre_prets']
            taux_croissance = None
            if montant_precedent is not None:
                if montant_precedent > 0:
                    taux_croissance = round(((total - montant_precedent) / montant_precedent) * 100, 1)
                elif total > 0:
                    taux_croissance = 100.0
                else:
                    taux_croissance = 0.0

            donnees_mois.append({
                'mois': mois_nom,
                'total_montant': total,
                'nombre_prets': nb,
                'croissance': taux_croissance,
            })

            labels_graphique.append(mois_nom)
            montants_graphique.append(total)
            montant_precedent = total

    total_cumule = sum(d['total_montant'] for d in donnees_mois)
    total_nombre = sum(d['nombre_prets'] for d in donnees_mois)
    evolution_globale = None
    if len(donnees_mois) >= 2 and donnees_mois[0]['total_montant'] > 0:
        dernière_val = donnees_mois[-1]['total_montant']
        première_val = donnees_mois[0]['total_montant']
        evolution_globale = round(((dernière_val - première_val) / première_val) * 100, 1)

    context = {
        'partenaire': partenaire_obj,
        'groupes': groupes,
        'selected_groupe': int(groupe_id) if groupe_id else None,
        'donnees_mois': donnees_mois,
        'total_cumule': total_cumule,
        'total_nombre': total_nombre,
        'evolution_globale': evolution_globale,
        'labels_json': json.dumps(labels_graphique),
        'montants_json': json.dumps(montants_graphique),
        'derniers_prets': prets_query.order_by('-date_demande')[:10],
    }

    return render(request, 'core/prets_statistiques.html', context)


def approbation_finale_directeur(request, pret_id):
    pret = get_object_or_404(Pret, id=pret_id)

    if request.method == 'POST':
        action = request.POST.get('action')
        if action == 'approuve':
            pret.statut = 'APPROUVE'
            pret.date_approbation = timezone.now()
            messages.success(request, f"Le prêt #{pret.id} a été approuvé avec succès.")
        elif action == 'rejete':
            pret.statut = 'REJETE'
            messages.warning(request, f"Le prêt #{pret.id} a été rejeté.")

        pret.save()
        return redirect('core:manager_dashboard')

    return render(request, 'core/approbation_pret.html', {'pret': pret})
# ==============================================================================
# ESPACE PARTENAIRES
# ==============================================================================

@login_required(login_url='/partner/login/')
@user_passes_test(check_is_partner, login_url='/partner/login/')
def partner_members_list_view(request):
    user = request.user
    partenaire_obj = Partenaire.objects.filter(nom=user.username).first()

    if partenaire_obj:
        membres = Membre.objects.filter(groupe__partenaire=partenaire_obj)
    else:
        membres = Membre.objects.none()

    query = request.GET.get('q', '')
    if query:
        membres = membres.filter(
            Q(nom__icontains=query) |
            Q(prenom__icontains=query) |
            Q(telephone__icontains=query)
        )

    context = {
        'membres': membres,
        'partenaire': partenaire_obj,
        'query': query,
    }
    return render(request, 'core/partner_members_list.html', context)


@login_required(login_url='/partner/login/')
@user_passes_test(check_is_partner, login_url='/partner/login/')
def partner_register_member_view(request):
    user = request.user
    partenaire_obj = Partenaire.objects.filter(nom=user.username).first()

    if request.method == 'POST':
        form = PartnerMemberOnboardingForm(request.POST)
        if form.is_valid():
            membre = form.save()
            messages.success(request, f"Le membre {membre.prenom} {membre.nom} a été enregistré avec succès.")
            return redirect('core:partner_members')
        else:
            messages.error(request, "Veuillez corriger les erreurs dans le formulaire.")
    else:
        form = PartnerMemberOnboardingForm()

    context = {
        'form': form,
        'partenaire': partenaire_obj,
    }
    return render(request, 'core/partner_register_member.html', context)


@login_required(login_url='/partner/login/')
@user_passes_test(check_is_partner, login_url='/partner/login/')
def partner_member_detail_view(request, member_id):
    user = request.user
    partenaire_obj = Partenaire.objects.filter(nom=user.username).first()
    base_queryset = Membre.objects.select_related('groupe')

    if partenaire_obj:
        membre = get_object_or_404(base_queryset, id=member_id, groupe__partenaire=partenaire_obj)
    else:
        membre = get_object_or_404(base_queryset, id=member_id)

    transactions = TransactionHistory.objects.filter(membre=membre).order_by('-date_transaction')
    prets_en_cours = Pret.objects.filter(membre=membre).order_by('-date_demande')
    prets_en_cours_count = prets_en_cours.filter(
        Q(statut__in=['ACCORDE', 'EN_COURS', 'EN_ATTENTE', 'En attente']) | Q(statut__isnull=True)
    ).count()
    presences_list = Presence.objects.filter(membre_id=membre.id).order_by('-date_reunion')
    total_presences = presences_list.filter(Q(status__iexact='Present') | Q(status__iexact='Présent')).count()
    total_absences = presences_list.filter(status__iexact='Absent').count()
    total_excuses = presences_list.filter(Q(status__iexact='Excuse') | Q(status__iexact='Excusé')).count()

    context = {
        'membre': membre,
        'partenaire': partenaire_obj,
        'transactions': transactions,
        'prets_en_cours': prets_en_cours,
        'prets_en_cours_count': prets_en_cours_count,
        'presences_list': presences_list,
        'total_presences': total_presences,
        'total_absences': total_absences,
        'total_excuses': total_excuses,
    }
    return render(request, 'core/partner_member_detail.html', context)


@login_required
def partner_deposit_view(request):
    if request.method == 'POST':
        membre_identifier = request.POST.get('telephone') or request.POST.get('membre_identifier')
        montant_str = request.POST.get('montant')
        motif = request.POST.get('motif', 'Dépôt régulier')

        if not membre_identifier or not montant_str:
            messages.error(request, "Veuillez fournir un membre et un montant.")
            return redirect('core:partner_deposit')

        try:
            montant = Decimal(str(montant_str))
            if montant <= 0:
                raise ValueError("Le montant doit être positif.")
        except (ValueError, TypeError):
            messages.error(request, "Veuillez entrer un montant valide (supérieur à 0).")
            return redirect('core:partner_deposit')
        try:
            membre = Membre.objects.get(telephone=membre_identifier)
        except Membre.DoesNotExist:
            try:
                clean_id = membre_identifier.replace('#', '').strip()
                membre = Membre.objects.get(id=clean_id)
            except (Membre.DoesNotExist, ValueError):
                messages.error(request, f"Aucun membre trouvé avec l'identifiant : {membre_identifier}")
                return redirect('core:partner_deposit')

        try:
            with db_transaction.atomic():
                if motif == 'Remboursement de crédit':
                    type_op = 'Remboursement Crédit'
                    description = "Remboursement de crédit enregistré par l'opérateur."
                elif motif == 'Caisse sociale' or "caisse sociale" in motif.lower():
                    type_op = 'CAISSE_SOCIALE'
                    description = "Cotisation caisse sociale."
                else:
                    type_op = 'DEPOT'
                    description = motif or "Dépôt régulier"

                TransactionHistory.objects.create(
                    membre=membre,
                    montant=montant,
                    type_operation=type_op,
                    description=description,
                    statut='ACTIF',
                    date_transaction=timezone.now()
                )

                if type_op == 'CAISSE_SOCIALE':
                    if membre.caisse_sociale is None:
                        membre.caisse_sociale = Decimal('0')
                    membre.caisse_sociale += montant
                    membre.save()
                elif type_op == 'DEPOT':
                    if membre.solde_epargne is None:
                        membre.solde_epargne = Decimal('0')
                    membre.solde_epargne += montant
                    membre.save()
                elif type_op == 'Remboursement Crédit':
                    if hasattr(membre, 'calculer_credits'):
                        credits_info = membre.calculer_credits
                        if credits_info and credits_info.get('restant', 0) <= 0:
                            membre.prets.filter(statut='ATTRIBUE').update(statut='SOLDE', est_archive=True)

            messages.success(request,
                             f"✅ Opération de {montant:,.0f} BIF enregistrée avec succès pour {membre.prenom} {membre.nom}.")
            return redirect('core:partner_dashboard')

        except Exception as e:
            messages.error(request, f"Une erreur s'est produite lors de l'enregistrement : {str(e)}")
            return redirect('core:partner_deposit')

    prefill_member = request.GET.get('member_id', '')
    context = {'prefill_member': prefill_member}

    if 'get_brb_exchange_rates' in globals():
        context['brb_rates'] = get_brb_exchange_rates()

    return render(request, 'core/partner_deposit.html', context)


@login_required(login_url='/partner/login/')
@user_passes_test(check_is_partner, login_url='/partner/login/')
def presences_statistiques_view(request):
    user = request.user
    partenaire_obj = Partenaire.objects.filter(nom=user.username).first()

    from core.models import Groupe, Presences
    groupes = Groupe.objects.filter(partenaire=partenaire_obj) if partenaire_obj else Groupe.objects.all()

    if partenaire_obj:
        membres = Membre.objects.filter(groupe__partenaire=partenaire_obj)
    else:
        membres = Membre.objects.all()

    groupe_id = request.GET.get('groupe')
    if groupe_id:
        membres = membres.filter(groupe_id=groupe_id)

    for membre in membres:
        try:
            pres_list = Presences.objects.filter(membre=membre)
            membre.nb_presences = pres_list.filter(status__iexact='Present').count() + pres_list.filter(status__iexact='Présent').count()
            membre.nb_absences = pres_list.filter(status__iexact='Absent').count()
            membre.nb_excuses = pres_list.filter(status__iexact='Excuse').count() + pres_list.filter(status__iexact='Excusé').count()
        except Exception:
            membre.nb_presences = 0
            membre.nb_absences = 0
            membre.nb_excuses = 0

    context = {
        'partenaire': partenaire_obj,
        'groupes': groupes,
        'selected_groupe': int(groupe_id) if groupe_id else None,
        'membres': membres,
    }
    return render(request, 'core/presences_statistiques.html', context)

# ==============================================================================
# RAPPORTS ET EXPORTS (EXCEL / PDF)
# ==============================================================================

def tout_recuperer_donnees_caisse(request):
    selected_gid = request.GET.get('selected_gid', '')
    selected_member_id = request.GET.get('selected_member_id', '')
    mois_filtre = request.GET.get('mois_filtre', datetime.now().strftime('%Y-%m'))

    try:
        annee, mois = map(int, mois_filtre.split('-'))
        prefixe_mois = f"{annee}-{mois:02d}"
    except ValueError:
        prefixe_mois = datetime.now().strftime('%Y-%m')

    membres_qs = Membre.objects.filter(is_active=True)
    if selected_gid:
        membres_qs = membres_qs.filter(groupe_id=selected_gid)
    if selected_member_id:
        membres_qs = membres_qs.filter(id=selected_member_id)

    dates_reunions_brutes = HistoriqueEpargne.objects.filter(
        date_reunion__startswith=prefixe_mois
    ).values_list('date_reunion', flat=True).distinct().order_by('date_reunion')

    dates_reunions_formatees = []
    for d in dates_reunions_brutes:
        if isinstance(d, str) and len(d) >= 10:
            dates_reunions_formatees.append(f"{d[8:10]}/{d[5:7]}")
        elif hasattr(d, 'strftime'):
            dates_reunions_formatees.append(d.strftime('%d/%m'))
        else:
            dates_reunions_formatees.append(str(d))

    pivot_sociale = []

    for m in membres_qs:
        report_anterieur = HistoriqueEpargne.objects.filter(
            membre_id=m.id,
            date_reunion__lt=f"{prefixe_mois}-01"
        ).aggregate(Sum('caisse_sociale'))['caisse_sociale__sum'] or 0

        montants_mois = []
        sum_mois = 0
        for d_brute in dates_reunions_brutes:
            valeur = HistoriqueEpargne.objects.filter(
                membre_id=m.id,
                date_reunion=d_brute
            ).aggregate(Sum('caisse_sociale'))['caisse_sociale__sum'] or 0
            montants_mois.append(valeur)
            sum_mois += valeur

        cumul_actuel = report_anterieur + sum_mois

        pivot_sociale.append({
            'id': m.id, 'nom_complet': f"{m.prenom or ''} {m.nom}".strip(),
            'report_anterieur': report_anterieur, 'montants': montants_mois,
            'total_mois': sum_mois, 'cumul_actuel': cumul_actuel,
        })

    return pivot_sociale, dates_reunions_formatees, mois_filtre


@login_required
def caisse_sociale_view(request):
    user = request.user
    partenaire_obj = Partenaire.objects.filter(nom=user.username).first()
    groupe_id = request.GET.get('groupe')
    groupes = Groupes.objects.all()

    if partenaire_obj:
        groupes = groupes.filter(partenaire=partenaire_obj)

    selected_groupe = None
    if groupe_id:
        selected_groupe = groupes.filter(id=groupe_id).first()
    elif groupes.exists():
        selected_groupe = groupes.first()

    membres = Membres.objects.filter(groupe=selected_groupe) if selected_groupe else Membres.objects.none()
    decaissements = DecaissementSocial.objects.filter(groupe_id=selected_groupe.id).order_by(
        '-id') if selected_groupe else []

    if request.method == 'POST':
        form = DecaissementSocialForm(request.POST, groupe=selected_groupe)
        if form.is_valid():
            decaissement = form.save(commit=False)
            decaissement.groupe_id = selected_groupe.id
            decaissement.date_decaissement = timezone.now().strftime('%Y-%m-%d')
            decaissement.heure_enregistrement = timezone.now().strftime('%H:%M:%S')
            decaissement.enregistre_par = request.user.username
            decaissement.montant_rembourse = 0.0

            if decaissement.montant_decaisse > selected_groupe.solde_caisse_sociale_groupe:
                messages.error(request,
                               "Le montant demandé dépasse le solde disponible dans la Caisse Sociale du groupe.")
            else:
                decaissement.save()
                membre_beneficiaire = decaissement.membre
                if membre_beneficiaire:
                    try:
                        montant_retire = Decimal(str(decaissement.montant_decaisse or 0).replace(',', '.'))
                        solde_actuel = Decimal(str(membre_beneficiaire.caisse_sociale or 0).replace(',', '.'))
                        nouveau_solde = max(Decimal('0'), solde_actuel - montant_retire)
                        Membres.objects.filter(pk=membre_beneficiaire.pk).update(caisse_sociale=nouveau_solde)

                        from .models import TransactionHistory
                        TransactionHistory.objects.create(
                            membre=membre_beneficiaire,
                            type_operation='DECAISSEMENT_SOCIAL',
                            montant=montant_retire,
                            date_transaction = timezone.now()
                        )
                    except Exception as e:
                        print(f"Erreur lors de la soustraction de la caisse sociale: {e}")

                messages.success(request,
                                 f"Décaissement de {decaissement.montant_decaisse} BIF enregistré pour {decaissement.membre}.")
                return redirect(f"{request.path}?groupe={selected_groupe.id}")
    else:
        form = DecaissementSocialForm(groupe=selected_groupe)

    context = {
        'groupes': groupes,
        'selected_groupe': selected_groupe,
        'groupe': selected_groupe,
        'membres': membres,
        'decaissements': decaissements,
        'form': form,
        'partenaire': partenaire_obj,
    }
    return render(request, 'core/caisse_sociale.html', context)


def export_caisse_sociale_excel(request):
    if not openpyxl:
        return HttpResponse("La bibliothèque openpyxl n'est pas installée.", status=500)

    pivot_sociale, dates_reunions, mois_filtre = tout_recuperer_donnees_caisse(request)

    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = f"Caisse Sociale {mois_filtre}"

    headers = ["ID", "Membre", "Report Antérieur (BIF)"] + [f"📅 {d}" for d in dates_reunions] + ["Total Mois (BIF)",
                                                                                                 "Cumul Actuel (BIF)"]
    ws.append(headers)

    header_fill = PatternFill(start_color="2C3E50", end_color="2C3E50", fill_type="solid")
    header_font = Font(color="FFFFFF", bold=True)
    for col_num, header in enumerate(headers, 1):
        cell = ws.cell(row=1, column=col_num)
        cell.fill = header_fill
        cell.font = header_font
        cell.alignment = Alignment(horizontal="center", vertical="center")

    for line in pivot_sociale:
        row = [line['id'], line['nom_complet'], line['report_anterieur']] + line['montants'] + [line['total_mois'],
                                                                                                line['cumul_actuel']]
        ws.append(row)

    response = HttpResponse(content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    response['Content-Disposition'] = f'attachment; filename="Caisse_Sociale_{mois_filtre}.xlsx"'
    wb.save(response)
    return response


@login_required
def groupe_registres_view(request, groupe_id=None):
    user = request.user
    partenaire_obj = Partenaire.objects.filter(nom=user.username).first()
    groupes = Groupes.objects.all()
    if partenaire_obj:
        groupes = groupes.filter(partenaire=partenaire_obj)

    req_groupe_id = request.GET.get('groupe') or request.GET.get('groupe_id') or groupe_id
    selected_groupe = None
    if req_groupe_id:
        selected_groupe = groupes.filter(id=req_groupe_id).first()
    if not selected_groupe and groupes.exists():
        selected_groupe = groupes.first()

    active_tab = request.GET.get('tab', 'caisse_sociale')
    membres = Membres.objects.filter(groupe=selected_groupe) if selected_groupe else Membres.objects.none()
    decaissements = DecaissementSocial.objects.filter(groupe_id=selected_groupe.id).order_by(
        '-id') if selected_groupe else []

    if request.method == 'POST' and active_tab == 'caisse_sociale':
        form = DecaissementSocialForm(request.POST, groupe=selected_groupe)
        if form.is_valid():
            decaissement = form.save(commit=False)
            decaissement.groupe_id = selected_groupe.id
            decaissement.date_decaissement = timezone.now().strftime('%Y-%m-%d')
            decaissement.heure_enregistrement = timezone.now().strftime('%H:%M:%S')
            decaissement.enregistre_par = request.user.username
            decaissement.montant_rembourse = 0.0

            if selected_groupe and decaissement.montant_decaisse > selected_groupe.solde_caisse_sociale_groupe:
                messages.error(request,
                               "Le montant demandé dépasse le solde disponible dans la Caisse Sociale du groupe.")
            else:
                decaissement.save()
                membre_beneficiaire = decaissement.membre
                if membre_beneficiaire:
                    try:
                        from .models import HistoriqueEpargne, TransactionHistory

                        montant_retire = Decimal(str(decaissement.montant_decaisse or 0).replace(',', '.'))
                        solde_actuel = Decimal(str(membre_beneficiaire.caisse_sociale or 0).replace(',', '.'))
                        nouveau_solde = max(Decimal('0'), solde_actuel - montant_retire)
                        type(membre_beneficiaire).objects.filter(pk=membre_beneficiaire.pk).update(
                            caisse_sociale=nouveau_solde)
                        HistoriqueEpargne.objects.create(
                            membre_id=membre_beneficiaire.id,
                            date_reunion=timezone.now().date(),
                            caisse_sociale=-montant_retire
                        )
                        TransactionHistory.objects.create(
                            membre=membre_beneficiaire,
                            type_operation='DECAISSEMENT_SOCIAL',
                            montant=montant_retire,
                            date_transaction=timezone.now()
                        )
                    except Exception as e:
                        print(f"Erreur lors de la déduction : {e}")

                messages.success(request,
                                 f"Décaissement de {decaissement.montant_decaisse} BIF enregistré pour {decaissement.membre}.")
                return redirect(f"{request.path}?groupe={selected_groupe.id}&tab=caisse_sociale")
    else:
        form = DecaissementSocialForm(groupe=selected_groupe)

    context = {
        'groupes': groupes,
        'selected_groupe': selected_groupe,
        'groupe': selected_groupe,
        'membres': membres,
        'decaissements': decaissements,
        'form': form,
        'active_tab': active_tab,
        'partenaire': partenaire_obj,
    }

    return render(request, 'core/registre_audit.html', context)


def export_caisse_sociale_pdf(request):
    if not pisa:
        return HttpResponse("La bibliothèque xhtml2pdf n'est pas installée.", status=500)

    pivot_sociale, dates_reunions, mois_filtre = tout_recuperer_donnees_caisse(request)
    context = {'pivot_sociale': pivot_sociale, 'dates_reunions': dates_reunions, 'mois_filtre': mois_filtre}

    html_string = render_to_string('pdf/caisse_sociale_pdf.html', context)
    response = HttpResponse(content_type='application/pdf')
    response['Content-Disposition'] = f'inline; filename="Caisse_Sociale_{mois_filtre}.pdf"'

    pisa_status = pisa.CreatePDF(html_string, dest=response, link_callback=link_callback)
    if pisa_status.err:
        return HttpResponse('Erreur lors de la génération du PDF', status=500)
    return response


def enregistrer_caisse_sociale_view(request):
    if request.method == 'POST':
        messages.success(request, "Cotisation enregistrée.")

    return redirect('core:manager_dashboard')


def export_members_excel(request):
    if not openpyxl:
        return HttpResponse("La bibliothèque openpyxl n'est pas installée.", status=500)

    search_query = request.GET.get('q', '')
    membres_qs = Membre.objects.all()
    if search_query:
        membres_qs = membres_qs.filter(
            Q(nom__icontains=search_query) | Q(prenom__icontains=search_query) | Q(telephone__icontains=search_query)
        )

    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Liste des Membres"
    headers = ["ID", "Nom & Prénom", "Sexe", "Âge", "Téléphone", "CNI", "Adresse Complète", "Solde Épargne (BIF)",
               "Crédit en cours (BIF)"]
    ws.append(headers)

    header_fill = PatternFill(start_color="3498DB", end_color="3498DB", fill_type="solid")
    header_font = Font(color="FFFFFF", bold=True)
    for col_num, header in enumerate(headers, 1):
        cell = ws.cell(row=1, column=col_num)
        cell.fill = header_fill
        cell.font = header_font
        cell.alignment = Alignment(horizontal="center")

    for m in membres_qs:
        adresse = f"{getattr(m, 'colline', '-')}, {getattr(m, 'quartier', '-')} - Av. {getattr(m, 'avenue', '-')} (N° {getattr(m, 'maison', 'N/A')})"
        row = [
            m.id, f"{m.nom or ''} {m.prenom or ''}".strip(), getattr(m, 'sexe', "N/A"),
            getattr(m, 'age', "N/A"), m.telephone or '', getattr(m, 'cni', "N/A"), adresse,
            getattr(m, 'solde_epargne', 0), getattr(m, 'credit_en_cours', 0)
        ]
        ws.append(row)

    response = HttpResponse(content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    response['Content-Disposition'] = 'attachment; filename="Membres_Sacco.xlsx"'
    wb.save(response)
    return response


def export_members_pdf(request):
    if not pisa:
        return HttpResponse("La bibliothèque xhtml2pdf n'est pas installée.", status=500)

    role = str(request.session.get('role', '')).lower()
    if 'membre_id' not in request.session or (
            'admin' not in role and 'gestionnaire' not in role and not request.user.is_staff):
        return redirect('core:login')

    search_query = request.GET.get('q', '')
    membres_qs = Membre.objects.all().order_by('nom')

    if search_query:
        membres_qs = membres_qs.filter(
            Q(nom__icontains=search_query) | Q(prenom__icontains=search_query) | Q(telephone__icontains=search_query)
        )

    context = {'membres': membres_qs}
    html_string = render_to_string('pdf/membres_pdf.html', context)
    response = HttpResponse(content_type='application/pdf')
    response['Content-Disposition'] = 'inline; filename="resume_membres_sacco.pdf"'

    pisa_status = pisa.CreatePDF(html_string, dest=response, link_callback=link_callback)
    if pisa_status.err:
        return HttpResponse('Erreur lors de la génération du PDF', status=500)
    return response


def export_transaction_pdf(request, transaction_id):
    transaction = get_object_or_404(TransactionHistory, id=transaction_id)
    response = HttpResponse(content_type='application/pdf')
    response['Content-Disposition'] = f'attachment; filename="recu_transaction_{transaction.id}.pdf"'
    doc = SimpleDocTemplate(response, pagesize=letter, rightMargin=40, leftMargin=40, topMargin=40, bottomMargin=40)
    elements = []
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle('TitleStyle', parent=styles['Heading1'], fontSize=20,
                                 textColor=colors.HexColor('#2c3e50'), alignment=1, spaceAfter=15)
    subtitle_style = ParagraphStyle('SubTitleStyle', parent=styles['Normal'], fontSize=10,
                                    textColor=colors.HexColor('#7f8c8d'), alignment=1, spaceAfter=25)
    bold_style = ParagraphStyle('BoldStyle', parent=styles['Normal'], fontSize=11, textColor=colors.HexColor('#2c3e50'))
    elements.append(Paragraph("<b>SACCO FINTECH</b>", title_style))
    elements.append(Paragraph("Reçu de Transaction Financière", subtitle_style))
    elements.append(Spacer(1, 10))
    nom_membre = f"{transaction.membre.prenom} {transaction.membre.nom}" if transaction.membre else "Membre inconnu"
    date_str = transaction.date_transaction.strftime('%d/%m/%Y à %H:%M') if transaction.date_transaction else "-"
    montant_str = f"{float(transaction.montant or 0):,.0f} BIF".replace(',', ' ')
    type_op = transaction.get_type_operation_display() if hasattr(transaction,
                                                                  'get_type_operation_display') else transaction.type_operation

    data = [
        [Paragraph("<b>Référence Reçu :</b>", bold_style), Paragraph(f"#{transaction.id}", styles['Normal'])],
        [Paragraph("<b>Date & Heure :</b>", bold_style), Paragraph(date_str, styles['Normal'])],
        [Paragraph("<b>Nom du Membre :</b>", bold_style), Paragraph(nom_membre, styles['Normal'])],
        [Paragraph("<b>Type d'opération :</b>", bold_style), Paragraph(str(type_op), styles['Normal'])],
        [Paragraph("<b>Montant :</b>", bold_style), Paragraph(f"<b>{montant_str}</b>", bold_style)],
        [Paragraph("<b>Description :</b>", bold_style),
         Paragraph(transaction.description or "Aucune description", styles['Normal'])],
    ]

    t = Table(data, colWidths=[150, 350])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#f8f9fa')),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 10),
        ('TOPPADDING', (0, 0), (-1, -1), 10),
        ('LEFTPADDING', (0, 0), (-1, -1), 12),
        ('RIGHTPADDING', (0, 0), (-1, -1), 12),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#e2e8f0')),
    ]))
    elements.append(t)
    doc.build(elements)
    return response


def export_all_transactions_pdf(request):
    if not pisa:
        return HttpResponse("La bibliothèque xhtml2pdf n'est pas installée.", status=500)

    search_query = request.GET.get('q', '')
    selected_type = request.GET.get('type_op', '')
    transactions = TransactionHistory.objects.all().order_by('-date_transaction')

    if search_query:
        transactions = transactions.filter(
            Q(membre__nom__icontains=search_query) | Q(membre__prenom__icontains=search_query)
        )
    if selected_type:
        transactions = transactions.filter(type_operation=selected_type)

    context = {'transactions': transactions}
    html_string = render_to_string('pdf/transactions_pdf.html', context, request=request)

    response = HttpResponse(content_type='application/pdf')
    response['Content-Disposition'] = 'inline; filename="Rapport_Financier_Transactions.pdf"'

    pisa_status = pisa.CreatePDF(html_string, dest=response, link_callback=link_callback)
    if pisa_status.err:
        return HttpResponse('Erreur lors de la génération du PDF', status=500)
    return response


def export_transactions_pdf(request):
    if not pisa:
        return HttpResponse("La bibliothèque xhtml2pdf n'est pas installée.", status=500)

    search_query = request.GET.get('q', '')
    selected_type = request.GET.get('type_op', '')
    transactions = TransactionHistory.objects.all().order_by('-date_transaction')

    if search_query:
        transactions = transactions.filter(
            Q(membre__nom__icontains=search_query) | Q(membre__prenom__icontains=search_query)
        )
    if selected_type:
        transactions = transactions.filter(type_operation=selected_type)

    context = {'transactions': transactions}
    html_string = render_to_string('pdf/transactions_pdf.html', context, request=request)

    response = HttpResponse(content_type='application/pdf')
    response['Content-Disposition'] = 'inline; filename="Rapport_Financier_Transactions.pdf"'

    pisa_status = pisa.CreatePDF(html_string, dest=response, link_callback=link_callback)
    if pisa_status.err:
        return HttpResponse('Erreur lors de la génération du PDF', status=500)
    return response

# ==============================================================================
# TICKETS ET SUPPORT COMMUNAUTAIRE
# ==============================================================================

def ticket_detail_view(request, ticket_id):
    ticket = get_object_or_404(TicketSupport, id=ticket_id)
    is_membre = request.session.get('user_type') == 'membre'

    if request.method == 'POST':
        contenu = request.POST.get('contenu')
        if contenu:
            if is_membre:
                membre = get_object_or_404(Membre, id=request.session.get('membre_id'))
                MessageTicket.objects.create(ticket=ticket, expediteur_membre=membre, contenu=contenu)
            elif request.user.is_authenticated:
                MessageTicket.objects.create(ticket=ticket, expediteur_user=request.user, contenu=contenu)
            return redirect('core:ticket_detail', ticket_id=ticket.id)

    return render(request, 'core/ticket_detail.html', {'ticket': ticket, 'is_membre': is_membre})


def contact_view(request):
    is_membre = request.session.get('user_type') == 'membre'

    if is_membre:
        membre = get_object_or_404(Membre, id=request.session.get('membre_id'))
        if request.method == 'POST':
            sujet = request.POST.get('sujet')
            contenu = request.POST.get('contenu')

            if sujet and contenu:
                ticket = TicketSupport.objects.create(sujet=sujet, membre=membre)
                MessageTicket.objects.create(ticket=ticket, expediteur_membre=membre, contenu=contenu)
                messages.success(request, "Votre message a été envoyé avec succès.")
                return redirect('core:ticket_detail', ticket_id=ticket.id)

        tickets = TicketSupport.objects.filter(membre=membre).order_by('-date_creation')
        return render(request, 'core/contact.html', {'tickets': tickets})

    elif request.user.is_authenticated:
        if request.user.groups.filter(name='Partenaires').exists():
            tickets = TicketSupport.objects.filter(partenaire_assigne=request.user).order_by('-date_creation')
        else:
            tickets = TicketSupport.objects.all().order_by('-date_creation')
        return render(request, 'core/contact_admin.html', {'tickets': tickets})

    return redirect('core:login')


def contact_public_view(request):
    if request.method == 'POST':
        messages.success(request, "Votre message a bien été envoyé. Nous vous répondrons très vite.")
        return redirect('core:contact_public')
    return render(request, 'core/contact_public.html')

# ==============================================================================
# FONCTIONS FACTICES / RESERVÉES
# ==============================================================================

def enregistrer_presences_view(request):
    if request.method == 'POST':
        messages.success(request, "Les présences ont été enregistrées avec succès.")
    return redirect('core:manager_dashboard')


def admin_reset_pin(request):
    role = str(request.session.get('role', '')).lower()
    if 'membre_id' not in request.session or ('admin' not in role and 'gestionnaire' not in role):
        return redirect('core:login')

    if request.method == 'POST':
        membre_id = request.POST.get('membre_id')
        nouveau_pin = request.POST.get('nouveau_pin')

        if membre_id and nouveau_pin:
            membre = get_object_or_404(Membre, id=membre_id)
            # Mettez à jour le champ PIN selon votre modèle (ex: pin ou code_pin)
            membre.pin = nouveau_pin
            membre.save()
            messages.success(request, f"Le code PIN pour le membre {membre.nom} a été réinitialisé avec succès.")
        else:
            messages.error(request, "Veuillez remplir tous les champs requis.")

        return redirect('core:manager_dashboard')

    membres = Membre.objects.all()
    return render(request, 'core/reset_pin.html', {'membres': membres})


def search_member_view(request):
    query = request.GET.get('q', '').strip()
    membres = []

    if query:
        membres = Membre.objects.filter(
            Q(nom__icontains=query) |
            Q(prenom__icontains=query) |
            Q(telephone__icontains=query) |
            Q(cni__icontains=query)
        )

    if request.headers.get('x-requested-with') == 'XMLHttpRequest':
        html = render_to_string('core/partials/member_search_results.html', {'membres': membres}, request=request)
        return HttpResponse(html)

    return render(request, 'core/search_member.html', {'membres': membres, 'query': query})

# ==============================================================================
# PAGES STATIQUES ET PAGES GÉNÉRALES
# ==============================================================================

def custom_csrf_failure(request, reason=""):
    context = {'reason': reason}

    return render(request, 'core/403_csrf.html', context, status=403)


def about_view(request):

    return render(request, 'core/about.html')


def privacy_policy_view(request):

    return render(request, 'core/privacy.html')

privacy_view = privacy_policy_view


def terms_view(request):

    return render(request, 'core/terms.html')

terms_of_service_view = terms_view


def accessibility_view(request):

    return render(request, 'core/accessibility.html')


def services_view(request):

    return redirect('/#services')


@login_required
def global_reports_view(request):
    context = {'partner_name': request.user.username}

    return render(request, 'core/partner_reports.html', context)


# ==============================================================================
# GESTION DES GROUPES & AFFECTATIONS
# ==============================================================================

@require_POST
def creer_groupe_view(request):
    role = str(request.session.get('role', '')).lower()
    if 'admin' not in role and 'gestionnaire' not in role and not request.user.is_staff:
        return redirect('core:login')

    nom_saisi = request.POST.get('nom_groupe') or request.POST.get('nom')
    if nom_saisi:
        Groupe.objects.create(nom_groupe=nom_saisi)
        messages.success(request, f"Le groupe '{nom_saisi}' a été créé.")
    return redirect('core:manager_dashboard')


@login_required
@require_POST
def modifier_taux_groupe_view(request, groupe_id):
    groupe = get_object_or_404(Groupe, id=groupe_id)

    nouveau_taux = request.POST.get('taux_interet_reunion') or request.POST.get('taux_interet')

    if nouveau_taux is not None and nouveau_taux.strip() != "":
        try:
            groupe.taux_interet_reunion = float(nouveau_taux)
            groupe.save()
            messages.success(
                request,
                f"Le taux d'intérêt pour le groupe '{groupe.nom_groupe}' a été mis à jour à {nouveau_taux}%."
            )
        except ValueError:
            messages.error(request, "Veuillez entrer un nombre valide pour le taux d'intérêt.")
    else:
        messages.warning(request, "Aucune valeur n'a été saisie pour le taux d'intérêt.")

    return redirect(request.META.get('HTTP_REFERER', 'core:manager_dashboard'))


@login_required
def archiver_groupe_view(request, groupe_id):
    if request.method == 'POST':
        groupe = get_object_or_404(Groupe, pk=groupe_id)
        groupe.est_archive = True
        groupe.save()

    return redirect('/manager/?tab=groupes')


@require_POST
def restaurer_groupe_view(request, groupe_id):
    groupe = get_object_or_404(Groupe, id=groupe_id)
    groupe.est_archive = False
    groupe.save()
    messages.success(request, f"Le groupe {groupe.nom_groupe} a été restauré.")

    return redirect('core:manager_dashboard')


@require_POST
def retirer_groupe_view(request, membre_id):
    membre = get_object_or_404(Membre, id=membre_id)
    membre.groupe = None
    membre.save()
    messages.success(request, f"{membre.nom} a été retiré de son groupe.")

    return redirect(request.META.get('HTTP_REFERER', 'core:manager_dashboard'))


@require_POST
def changer_groupe_view(request, membre_id):
    membre = get_object_or_404(Membre, id=membre_id)
    nouveau_groupe_id = request.POST.get('nouveau_groupe_id')

    if nouveau_groupe_id:
        nouveau_groupe = get_object_or_404(Groupe, id=nouveau_groupe_id)
        membre.groupe = nouveau_groupe
        membre.save()
        messages.success(request, f"{membre.nom} a été déplacé vers le groupe {nouveau_groupe.nom_groupe}.")

    return redirect('core:manager_dashboard')


@require_POST
def assigner_partenaire_groupe_view(request, groupe_id):
    groupe = get_object_or_404(Groupe, id=groupe_id)
    partenaire_id = request.POST.get('partenaire_id')

    if partenaire_id:
        partenaire = get_object_or_404(Partenaire, id=partenaire_id)
        groupe.partenaire = partenaire
        groupe.save()
        messages.success(request, f"Le partenaire {partenaire.nom} a été assigné au groupe {groupe.nom_groupe}.")

    return redirect('core:manager_dashboard')


@require_POST
def admin_planifier_reunion_view(request):
    groupe_id = request.POST.get('groupe_id')
    date_reunion = request.POST.get('prochaine_reunion') or request.POST.get('date_reunion')

    if groupe_id and groupe_id.strip() != "" and date_reunion:
        try:
            groupe = Groupe.objects.get(id=groupe_id)
            groupe.date_reunion_prochaine = date_reunion
            groupe.save()
            messages.success(request, "La date de la prochaine réunion a été planifiée.")
        except Groupe.DoesNotExist:
            messages.error(request, "Erreur : Groupe introuvable.")
    else:
        messages.error(request, "Erreur : Veuillez sélectionner un groupe valide et une date.")

    return redirect('core:manager_dashboard')


# ==============================================================================
# SAISIES FINANCIÈRES & OPÉRATIONS HEBDOMADAIRES
# ==============================================================================

@login_required
def grant_credit_view(request, membre_id):
    membre = get_object_or_404(Membre, id=membre_id)

    if request.method == 'POST':
        montant_str = request.POST.get('montant')
        taux_interet_str = request.POST.get('taux_interet', '50')
        duree_mois_str = request.POST.get('duree_mois', '1')
        motif = request.POST.get('motif', 'Crédit ordinaire')

        try:
            montant = float(montant_str)
            taux_interet = float(taux_interet_str)
            duree_mois = int(duree_mois_str)

            if montant <= 0:
                raise ValueError("Le montant du crédit doit être supérieur à zéro.")
        except (ValueError, TypeError):
            messages.error(request, "Veuillez entrer des valeurs numériques valides.")
            return redirect('core:grant_credit', membre_id=membre.id)

        try:
            with db_transaction.atomic():
                '''
                nouveau_credit = Credit.objects.create(
                    membre=membre,
                    montant_principal=montant,
                    taux_interet=taux_interet,
                    duree_mois=duree_mois,
                    statut='ACTIF', # Statuts possibles: EN_ATTENTE, ACTIF, CLOTURE, EN_RETARD
                    date_octroi=timezone.now()
                )
                '''

                Transaction.objects.create(
                    membre=membre,
                    type_transaction='CREDIT',
                    type_operation='Octroi de Crédit',
                    montant=montant,
                    motif=f"{motif} - {duree_mois} mois à {taux_interet}%",
                    statut='Validé',
                    effectue_par=request.user,
                    date_transaction=timezone.now()
                )

            messages.success(request, f"Crédit de {montant:,.0f} BIF octroyé avec succès à {membre.prenom} {membre.nom}.")
            return redirect('core:manager_dashboard')

        except Exception as e:
            messages.error(request, f"Erreur lors de l'octroi du crédit : {str(e)}")
            return redirect('core:grant_credit', membre_id=membre.id)

    context = {
        'membre': membre,
    }
    return render(request, 'core/grant_credit.html', context)


def apply_penalty_view(request, membre_id):
    membre = get_object_or_404(Membre, id=membre_id)

    if request.method == 'POST':
        taux = request.POST.get('taux')
        mois_retard = request.POST.get('mois_retard')

        if taux and mois_retard:
            messages.success(request, f"Pénalité appliquée avec succès pour le membre {membre.nom}.")
        else:
            messages.error(request, "Veuillez renseigner tous les champs obligatoires.")

        return redirect('core:manager_dashboard')

    return render(request, 'core/apply_penalty.html', {'membre': membre})


@login_required
def update_loan_status_view(request, pret_id, action):
    pret = get_object_or_404(Pret, pk=pret_id)
    action_clean = action.lower().strip()

    if action_clean in ['approuver', 'valider', 'approve']:
        pret.statut = 'APPROUVE'
        messages.success(request, f"✅ Le prêt #{pret.id} a été approuvé avec succès.")

    elif action_clean in ['rejeter', 'refuser', 'reject']:
        pret.statut = 'REJETE'
        pret.est_archive = True
        messages.warning(request, f"❌ Le prêt #{pret.id} a été rejeté et archivé.")

    elif action_clean in ['attribuer', 'accorder', 'octroyer', 'debourser']:
        with transaction.atomic():
            pret.statut = 'ATTRIBUE'
            pret.date_traitement = timezone.now()

            if hasattr(pret, 'membre') and pret.membre:
                pret.membre.solde_epargne = (pret.membre.solde_epargne or 0.0) + float(pret.montant)
                pret.membre.save()

        messages.success(request, f"💰 Le prêt #{pret.id} a été attribué (fonds virés/déboursés).")

    elif action_clean in ['archiver', 'archive']:
        pret.est_archive = True
        messages.info(request, f"📁 Le prêt #{pret.id} a été archivé.")

    elif action_clean in ['annuler', 'cancel']:
        pret.statut = 'ANNULE'
        pret.est_archive = True
        messages.info(request, f"ℹ️ Le prêt #{pret.id} a été annulé.")

    else:
        messages.error(request, f"L'action '{action}' n'est pas reconnue.")
        referer = request.META.get('HTTP_REFERER')
        return redirect(referer if referer else 'core:manager_dashboard')

    pret.save()

    referer = request.META.get('HTTP_REFERER')
    if referer:
        return redirect(referer)
    return redirect('core:manager_dashboard')


@login_required
def enregistrer_remboursement_view(request, membre_id):
    membre = get_object_or_404(Membre, pk=membre_id)

    if request.method == 'POST':
        try:
            montant_verse = float(request.POST.get('montant_remboursement', 0))
        except (ValueError, TypeError):
            montant_verse = 0.0

        if montant_verse > 0:
            with transaction.atomic():
                TransactionHistory.objects.create(
                    membre=membre,
                    montant=Decimal(str(montant_verse)),
                    type_operation='Remboursement Crédit',
                    description="Remboursement de crédit effectué auprès du partenaire."
                )

                if hasattr(membre, 'calculer_credits'):
                    credits_info = membre.calculer_credits
                    if credits_info['restant'] <= 0:
                        membre.prets.filter(statut='ATTRIBUE').update(statut='SOLDE', est_archive=True)

            messages.success(
                request,
                f"✅ Remboursement de {montant_verse:,.0f} BIF enregistré avec succès pour {membre.prenom} {membre.nom}."
            )
        else:
            messages.error(request, "Le montant du remboursement doit être supérieur à 0.")

    referer = request.META.get('HTTP_REFERER')
    return redirect(referer if referer else 'core:partner_dashboard')

# ==============================================================================
# RAPPORTS ET EXPORTS (EXCEL / PDF)
# ==============================================================================

@login_required
def financial_report_view(request):
    start_date = request.GET.get('start_date')
    end_date = request.GET.get('end_date')

    transactions = Transaction.objects.all()

    if start_date:
        transactions = transactions.filter(date_transaction__gte=start_date)
    if end_date:
        transactions = transactions.filter(date_transaction__lte=end_date)

    total_depots = transactions.filter(type_transaction='DEPOT').aggregate(Sum('montant'))['montant__sum'] or 0
    total_retraits = transactions.filter(type_transaction='RETRAIT').aggregate(Sum('montant'))['montant__sum'] or 0
    solde_net = total_depots - total_retraits
    total_prets = 0
    try:
        total_prets = Pret.objects.filter(statut__in=['APPROUVE', 'ACCORDE']).aggregate(Sum('montant'))['montant__sum'] or 0
    except Exception:
        pass
    recent_transactions = transactions.select_related('membre').order_by('-id')[:20]

    context = {
        'total_depots': total_depots,
        'total_retraits': total_retraits,
        'solde_net': solde_net,
        'total_prets': total_prets,
        'recent_transactions': recent_transactions,
        'start_date': start_date or '',
        'end_date': end_date or '',
    }

    return render(request, 'core/financial_report.html', context)


@login_required(login_url='/partner/login/')
def export_transactions_csv(request):
    response = HttpResponse(content_type='text/csv')
    response['Content-Disposition'] = 'attachment; filename="transactions.csv"'

    writer = csv.writer(response)
    writer.writerow(['Membre', 'Date de Réunion', 'Épargne', 'Caisse Sociale'])

    historiques = HistoriqueEpargne.objects.select_related('membre').all()
    for h in historiques:
        writer.writerow([
            str(h.membre),
            getattr(h, 'date_reunion', ''),
            getattr(h, 'montant_epargne', 0),
            getattr(h, 'montant_social', 0),
        ])

    return response

# ==============================================================================
# FONCTIONS FACTICES / RESERVÉES
# ==============================================================================

def transaction_detail_view(request, transaction_id):
    transaction = get_object_or_404(TransactionHistory, id=transaction_id)
    return render(request, 'core/transaction_detail.html', {'transaction': transaction})


def edit_transaction_view(request, transaction_id):
    transaction = get_object_or_404(TransactionHistory, id=transaction_id)

    if request.method == 'POST':
        montant = request.POST.get('montant')
        if montant:
            transaction.montant = montant
            transaction.save()
            messages.success(request, "La transaction a été mise à jour avec succès.")
            return redirect('core:transaction_detail', transaction_id=transaction.id)

    context = {'transaction': transaction}
    return render(request, 'core/edit_transaction.html', context)


def delete_transaction_view(request, transaction_id):
    transaction = get_object_or_404(TransactionHistory, id=transaction_id)

    if request.method == 'POST':
        transaction.delete()
        messages.success(request, "La transaction a été supprimée avec succès.")
        return redirect('core:dashboard')

    context = {'transaction': transaction}
    return render(request, 'core/delete_transaction.html', context)


def request_loan_view(request):
    role = str(request.session.get('role', '')).lower()
    if role == 'partenaire' or (request.user.is_authenticated and Partenaire.objects.filter(nom=request.user.username).exists()):
        messages.warning(request, "Les comptes partenaires ne peuvent pas demander de prêts. Vous n'avez accès qu'aux statistiques.")
        return redirect('core:partner_dashboard')

    membre_id = request.session.get('membre_id')
    membre = get_object_or_404(Membre, id=membre_id) if membre_id else None

    if request.method == 'POST':
        form = LoanRequestForm(request.POST)
        if form.is_valid():
            loan_request = form.save(commit=False)

            if membre:
                loan_request.membre = membre
                if membre.groupe and hasattr(membre.groupe, 'taux_interet_reunion'):
                    loan_request.taux_interet = membre.groupe.taux_interet_reunion
                else:
                    loan_request.taux_interet = 5.00

            loan_request.duree_mois = 3
            loan_request.date_echeance = timezone.now().date() + timedelta(days=90)
            montant = loan_request.montant_demande or loan_request.montant or 0
            interet = (montant * loan_request.taux_interet) / 100
            loan_request.montant_total_a_rembourser = montant + interet

            loan_request.save()
            messages.success(request, "Votre demande de prêt (sur 3 mois) a été soumise avec succès !")
            return redirect('core:dashboard')
    else:
        form = LoanRequestForm()

    context = {'form': form, 'membre': membre}
    return render(request, 'core/loan_request.html', context)


def loan_detail_view(request, pret_id):
    pret = get_object_or_404(Pret, pk=pret_id)

    is_ajax = request.headers.get('x-requested-with') == 'XMLHttpRequest' or 'application/json' in request.headers.get(
        'Accept', '')

    if is_ajax:
        return JsonResponse({
            "status": "success",
            "data": {
                "id": pret.id,
                "montant": getattr(pret, 'montant', getattr(pret, 'montant_demande', 0)),
                "motif": getattr(pret, 'motif', ''),
                "statut": getattr(pret, 'statut', 'EN_ATTENTE'),
            }
        })

    context = {'pret': pret}
    return render(request, 'core/loan_detail.html', context)


def loan_calculator_view(request):
    montant = request.GET.get('montant') or request.POST.get('montant')
    taux = request.GET.get('taux') or request.POST.get('taux')
    duree = request.GET.get('duree') or request.POST.get('duree')

    mensualite = None
    if montant and taux and duree:
        try:
            m = float(montant)
            t = float(taux) / 100 / 12
            d = int(duree)
            if t > 0:
                mensualite = (m * t * (1 + t) ** d) / ((1 + t) ** d - 1)
            else:
                mensualite = m / d
            mensualite = round(mensualite, 2)
        except (ValueError, ZeroDivisionError):
            pass

    is_ajax = request.headers.get('x-requested-with') == 'XMLHttpRequest' or 'application/json' in request.headers.get(
        'Accept', '')
    if is_ajax:
        return JsonResponse({"status": "success", "mensualite": mensualite})

    context = {'mensualite': mensualite}
    return render(request, 'core/loan_calculator.html', context)


def list_pending_loans_view(request):
    prets_en_attente = Pret.objects.filter(statut__iexact='EN_ATTENTE').order_by('-id')

    is_ajax = request.headers.get('x-requested-with') == 'XMLHttpRequest' or 'application/json' in request.headers.get(
        'Accept', '')
    if is_ajax:
        data = []
        for p in prets_en_attente:
            data.append({
                "id": p.id,
                "montant": getattr(p, 'montant', getattr(p, 'montant_demande', 0)),
                "motif": getattr(p, 'motif', ''),
                "statut": getattr(p, 'statut', 'EN_ATTENTE'),
            })
        return JsonResponse({"status": "success", "data": data})

    context = {'prets': prets_en_attente}
    return render(request, 'core/pending_loans.html', context)


def generate_loan_contract_pdf(request, transaction_id):
    pret = get_object_or_404(Pret, pk=transaction_id)

    context = {
        'pret': pret,
        'membre': getattr(pret, 'membre', None),
    }

    html_string = render_to_string('pdf/contrat_credit_pdf.html', context)
    response = HttpResponse(content_type='application/pdf')
    response['Content-Disposition'] = f'inline; filename="contrat_credit_{transaction_id}.pdf"'

    pisa_status = pisa.CreatePDF(html_string, dest=response)

    if pisa_status.err:
        return HttpResponse('Erreur lors de la génération du contrat PDF', status=500)

    return response


def valider_par_agent(request, pret_id):
    pret = get_object_or_404(Pret, pk=pret_id)

    if request.method == 'POST':
        nouveau_statut = request.POST.get('statut', 'APPROUVE')
        pret.statut = nouveau_statut
        pret.save()
        messages.success(request, f"Le statut du prêt #{pret.id} a été mis à jour avec succès.")

    return redirect('core:pending_loans')


@login_required
def member_qr_view(request):
    context = {}

    return render(request, 'core/member_qr.html', context)


@login_required
def security_pin_view(request):
    context = {}

    return render(request, 'core/security_pin.html', context)


@login_required
def admin_toggle_status(request, pk=None):
    if pk:
        membre = get_object_or_404(Membre, pk=pk)
        messages.success(request, f"Le statut a été mis à jour avec succès.")

    return redirect('core:manager_dashboard')


@login_required
def export_members_csv(request):
    response = HttpResponse(content_type='text/csv')
    response['Content-Disposition'] = 'attachment; filename="membres_sacco.csv"'

    writer = csv.writer(response)
    writer.writerow(['ID', 'Nom', 'Prénom', 'Téléphone', 'Rôle', 'Solde Épargne', 'Caisse Sociale'])

    membres = Membre.objects.all()
    for m in membres:
        writer.writerow([
            m.id,
            getattr(m, 'nom', ''),
            getattr(m, 'prenom', ''),
            getattr(m, 'telephone', ''),
            getattr(m, 'role', ''),
            getattr(m, 'solde_epargne', 0),
            getattr(m, 'caisse_sociale', 0),
        ])

    return response


@login_required
def export_loans_csv(request):
    response = HttpResponse(content_type='text/csv')
    response['Content-Disposition'] = 'attachment; filename="prets_sacco.csv"'

    writer = csv.writer(response)
    writer.writerow(['ID Prêt', 'Membre', 'Montant', 'Statut', 'Date Demande', 'Date Approbation'])

    prets = Pret.objects.select_related('membre').all()
    for p in prets:
        nom_membre = f"{p.membre.nom} {p.membre.prenom}" if p.membre else "Inconnu"
        writer.writerow([
            p.id,
            nom_membre,
            getattr(p, 'montant', 0),
            getattr(p, 'statut', ''),
            getattr(p, 'date_demande', ''),
            getattr(p, 'date_approbation', ''),
        ])

    return response


@login_required
def export_loans_excel(request):
    if not openpyxl:
        return HttpResponse("La bibliothèque openpyxl n'est pas installée.", status=500)

    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Rapport Prêts"

    headers = ['ID Prêt', 'Membre', 'Montant', 'Statut', 'Date Demande', 'Date Approbation']
    ws.append(headers)

    prets = Pret.objects.select_related('membre').all()
    for p in prets:
        nom_membre = f"{p.membre.nom} {p.membre.prenom}" if p.membre else "Inconnu"
        ws.append([
            p.id,
            nom_membre,
            float(getattr(p, 'montant', 0)),
            str(getattr(p, 'statut', '')),
            p.date_demande.strftime('%Y-%m-%d') if getattr(p, 'date_demande', None) else '',
            p.date_approbation.strftime('%Y-%m-%d') if getattr(p, 'date_approbation', None) else '',
        ])

    response = HttpResponse(content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    response['Content-Disposition'] = 'attachment; filename="prets_sacco.xlsx"'
    wb.save(response)
    return response


@login_required
def export_loans_pdf(request):
    if not pisa:
        return HttpResponse("La bibliothèque xhtml2pdf n'est pas installée.", status=500)

    prets = Pret.objects.select_related('membre').all()
    context = {'prets': prets}

    html_string = render_to_string('pdf/loans_pdf.html', context, request=request)
    response = HttpResponse(content_type='application/pdf')
    response['Content-Disposition'] = 'inline; filename="prets_sacco.pdf"'

    pisa_status = pisa.CreatePDF(html_string, dest=response)

    if pisa_status.err:
        return HttpResponse('Erreur lors de la génération du PDF des prêts', status=500)

    return response


def exporter_logs_csv(request):
    response = HttpResponse(content_type='text/csv')
    response['Content-Disposition'] = 'attachment; filename="journal_audit_sacco.csv"'

    writer = csv.writer(response)
    writer.writerow(['Date', 'Utilisateur', 'Action', 'Détails', 'Adresse IP'])

    logs = JournalAudit.objects.all().order_by('-date_action')
    for log in logs:
        writer.writerow([
            log.date_action.strftime('%Y-%m-%d %H:%M:%S'),
            log.utilisateur.username if log.utilisateur else 'Système',
            log.action,
            log.details,
            log.adresse_ip
        ])
    return response


def basculer_mode_maintenance(request):
    if request.method == 'POST':
        param, created = ParametreSysteme.objects.get_or_create(cle='MODE_MAINTENANCE')
        param.valeur = '1' if param.valeur != '1' else '0'
        param.save()
        messages.success(request, "Le mode maintenance a été mis à jour.")

    return redirect('/manager/?tab=parametres')


def cloturer_exercice(request):
    if request.method == 'POST':
        messages.success(request, "L'exercice financier a été clôturé avec succès.")

    return redirect('/manager/?tab=parametres')

@login_required
def ai_assistant_api(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            user_message = data.get('message', '').strip().lower()

            if not user_message:
                return JsonResponse({'reply': "Veuillez entrer un message."}, status=400)

            # Récupération sécurisée du membre via la session ou l'utilisateur
            membre_id = request.session.get('membre_id')
            membre = None
            if membre_id:
                membre = Membre.objects.filter(id=membre_id).first()
            elif hasattr(request.user, 'membre'):
                membre = request.user.membre

            prenom = membre.prenom if membre else "Membre"
            solde_epargne = membre.solde_epargne if membre and membre.solde_epargne else 0

            # Logique de réponse basée sur les mots-clés (Français et Kirundi)
            if 'solde' in user_message or 'amafranga' in user_message or 'epargne' in user_message:
                reply = f"Mwaramutse {prenom}. Votre solde d'épargne actuel est de {solde_epargne} BIF."
            elif 'reunion' in user_message or 'inama' in user_message:
                reply = f"Mwaramutse {prenom}. La prochaine réunion de votre groupe est planifiée selon le calendrier de votre section."
            elif 'pret' in user_message or 'credit' in user_message or 'imfashanyo' in user_message:
                reply = f"Mwaramutse {prenom}. Vous pouvez consulter les conditions d'octroi de prêt et utiliser notre simulateur directement depuis votre profil."
            else:
                reply = f"J'ai bien reçu votre message : '{user_message}'. En tant qu'assistant SACCO, je peux vous renseigner sur votre solde d'épargne, vos prêts ou vos réunions."

            return JsonResponse({'reply': reply})

        except Exception as e:
            return JsonResponse({'reply': f"Erreur de traitement : {str(e)}"}, status=500)

    return JsonResponse({'error': 'Méthode non autorisée.'}, status=405)


def generer_conseil_financier(membre):
    if not membre:
        return "Connectez-vous pour recevoir vos conseils financiers personnalisés."

    # Récupérer l'historique des épargnes du membre
    transactions_epargne = TransactionHistory.objects.filter(
        membre=membre, type_operation='EPARGNE'
    ).order_by('-date_transaction')

    total_epargne = membre.solde_epargne or 0
    nombre_depots = transactions_epargne.count()

    # Logique d'analyse simple et intelligente du coach
    if nombre_depots == 0:
        return (
            "🌱 **Conseil Coach** : Vous n'avez pas encore enregistré de dépôts d'épargne récents. "
            "Commencez dès cette semaine par de petites épargnes régulières pour solidifier votre profil financier !"
        )

    # Calcul d'une moyenne simple ou d'encouragement
    if total_epargne < 5000000000:
        return (
            f"💡 Votre solde actuel est de {total_epargne:,.0f} BIF. "
            "En augmentant légèrement vos cotisations d'épargne lors des prochaines réunions, "
            "vous vous rapprocherez plus vite de vos critères d'éligibilité aux prêts du groupe."
        )
    else:
        return (
            f"🎯 **Bravo !** Avec un solide solde d'épargne de {total_epargne:,.0f} BIF et {nombre_depots} dépôts enregistrés, "
            "votre constance est excellente. Vous maintenez une santé financière idéale pour prétendre à de nouveaux projets de crédit."
        )


def verifier_risque_defaut(membre):
    if not membre:
        return None

    prets_actifs = Pret.objects.filter(membre=membre, statut='APPROUVE')

    if not prets_actifs.exists():
        return None

    for pret in prets_actifs:
        alerte = {
            "niveau": "info",
            "message": f"Rappel d'échéance : Votre prêt en cours de {pret.montant:,.0f} BIF fait l'objet d'un suivi régulier. Pensez à planifier votre versement lors de la prochaine réunion."
        }
        return alerte
    return None


def calculer_credit_scoring(membre, pret=None):
    if not membre:
        return {"score": 0, "avis": "Inconnu", "couleur": "gray", "details": "Membre introuvable."}

    solde_epargne = membre.solde_epargne or 0
    nb_depots = TransactionHistory.objects.filter(membre=membre, type_operation='EPARGNE').count()

    score = 0
    if solde_epargne >= 500000:
        score += 40
    elif solde_epargne >= 200000:
        score += 30
    elif solde_epargne >= 50000:
        score += 20
    else:
        score += 10

    if nb_depots >= 5:
        score += 30
    elif nb_depots >= 2:
        score += 20
    else:
        score += 10

    score += 20  # Bonus de base de régularité

    if score >= 75:
        avis = "EXCELLENT - Prêt hautement recommandable"
        couleur = "green"
    elif score >= 50:
        avis = "MOYEN - Prêt accordé sous réserve de garanties"
        couleur = "amber"
    else:
        avis = "RISQUÉ - Dossier fragile, vigilance requise"
        couleur = "red"

    return {
        "score": score,
        "avis": avis,
        "couleur": couleur,
        "nb_depots": nb_depots,
        "solde_epargne": solde_epargne,
        "nom": f"{membre.prenom} {membre.nom}",
        "telephone": membre.telephone or "N/A",
        "montant_demande": pret.montant if pret else 0,
        "motif_pret": pret.motif if pret else "Demande générale de crédit",
        "pret_id": pret.id if pret else None,
    }

def detecter_anomalies_financieres(partenaire_obj):
    if not partenaire_obj:
        return []

    anomalies = []
    transactions = TransactionHistory.objects.filter(
        membre__groupe__partenaire=partenaire_obj
    ).order_by('-date_transaction')[:50]

    for tx in transactions:
        montant = tx.montant or 0
        if montant > 500000:
            anomalies.append({
                "type": "Montant Élevé / Suspect",
                "niveau": "eleve",
                "membre": f"{tx.membre.prenom} {tx.membre.nom}" if tx.membre else "Inconnu",
                "description": f"Transaction anormale de {montant:,.0f} BIF enregistrée.",
                "date": tx.date_transaction
            })

        elif tx.type_operation in ['RETRAIT', 'retrait'] and montant > 200000:
            anomalies.append({
                "type": "Retrait Important",
                "niveau": "moyen",
                "membre": f"{tx.membre.prenom} {tx.membre.nom}" if tx.membre else "Inconnu",
                "description": f"Retrait de {montant:,.0f} BIF nécessitant une vérification.",
                "date": tx.date_transaction
            })

    return anomalies


def recu_transaction_pdf_view(request, transaction_id):
    transaction = get_object_or_404(TransactionHistory, id=transaction_id)
    response = HttpResponse(content_type='application/pdf')
    response['Content-Disposition'] = f'attachment; filename="recu_transaction_{transaction.id}.pdf"'
    doc = SimpleDocTemplate(response, pagesize=letter, rightMargin=40, leftMargin=40, topMargin=40, bottomMargin=40)
    elements = []
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        'TitleStyle',
        parent=styles['Heading1'],
        fontSize=20,
        textColor=colors.HexColor('#2c3e50'),
        alignment=1,
        spaceAfter=15
    )
    subtitle_style = ParagraphStyle(
        'SubTitleStyle',
        parent=styles['Normal'],
        fontSize=10,
        textColor=colors.HexColor('#7f8c8d'),
        alignment=1,
        spaceAfter=25
    )
    bold_style = ParagraphStyle('BoldStyle', parent=styles['Normal'], fontSize=11, textColor=colors.HexColor('#2c3e50'))
    elements.append(Paragraph("<b>SACCO FINTECH</b>", title_style))
    elements.append(Paragraph("Reçu de Transaction Financière", subtitle_style))
    elements.append(Spacer(1, 10))
    nom_membre = f"{transaction.membre.prenom} {transaction.membre.nom}" if transaction.membre else "Membre inconnu"
    date_str = transaction.date_transaction.strftime('%d/%m/%Y à %H:%M') if transaction.date_transaction else "-"
    montant_str = f"{float(transaction.montant or 0):,.0f} BIF".replace(',', ' ')
    type_op = transaction.get_type_operation_display() if hasattr(transaction, 'get_type_operation_display') else transaction.type_operation

    data = [
        [Paragraph("<b>Référence Reçu :</b>", bold_style), Paragraph(f"#{transaction.id}", styles['Normal'])],
        [Paragraph("<b>Date & Heure :</b>", bold_style), Paragraph(date_str, styles['Normal'])],
        [Paragraph("<b>Nom du Membre :</b>", bold_style), Paragraph(nom_membre, styles['Normal'])],
        [Paragraph("<b>Type d'opération :</b>", bold_style), Paragraph(str(type_op), styles['Normal'])],
        [Paragraph("<b>Montant :</b>", bold_style), Paragraph(f"<b>{montant_str}</b>", bold_style)],
        [Paragraph("<b>Description :</b>", bold_style), Paragraph(transaction.description or "Aucune description", styles['Normal'])],
    ]

    t = Table(data, colWidths=[150, 350])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#f8f9fa')),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 10),
        ('TOPPADDING', (0, 0), (-1, -1), 10),
        ('LEFTPADDING', (0, 0), (-1, -1), 12),
        ('RIGHTPADDING', (0, 0), (-1, -1), 12),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#e2e8f0')),
    ]))

    elements.append(t)
    elements.append(Spacer(1, 40))
    footer_style = ParagraphStyle(
        'FooterStyle',
        parent=styles['Normal'],
        fontSize=9,
        textColor=colors.HexColor('#95a5a6'),
        alignment=1
    )
    elements.append(Paragraph("Ce document est un reçu officiel généré automatiquement par le système SaccoFINtech.", footer_style))

    doc.build(elements)
    return response