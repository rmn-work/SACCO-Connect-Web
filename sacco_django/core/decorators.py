from django.contrib.auth.decorators import user_passes_test
from django.core.exceptions import PermissionDenied


def partner_required(view_func):
    """
    Décorateur s'assurant que l'utilisateur est connecté
    et qu'il appartient au groupe ou possède le rôle de Partenaire.
    """

    def check_partner(user):
        if not user.is_authenticated:
            return False

        return getattr(user, 'is_partner', False) or user.is_superuser

    decorated_view = user_passes_test(
        check_partner,
        login_url='core:login'
    )(view_func)

    return decorated_view