from django.conf import settings
from .models import Membres

def social_links(request):
    return {
        'SOCIAL_LINKS': getattr(settings, 'SOCIAL_LINKS', {})
    }

def auth_member(request):
    """
    Rend disponible la variable 'current_member' dans TOUS les templates
    si un membre est connecté via la session.
    """
    membre_id = request.session.get('membre_id')
    if membre_id:
        try:
            member = Membres.objects.get(id=membre_id)
            return {'current_member': member, 'is_member_logged_in': True}
        except Membres.DoesNotExist:
            pass
    return {'current_member': None, 'is_member_logged_in': False}