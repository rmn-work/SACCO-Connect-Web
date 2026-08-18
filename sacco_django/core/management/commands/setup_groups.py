from django.core.management.base import BaseCommand
from django.contrib.auth.models import Group, Permission
from django.contrib.contenttypes.models import ContentType
from core.models import TransactionHistory

class Command(BaseCommand):
    help = 'Crée les groupes utilisateurs et attribue les permissions par défaut'

    def handle(self, *args, **kwargs):
        caissiers_group, created_c = Group.objects.get_or_create(name='Caissiers')
        managers_group, created_m = Group.objects.get_or_create(name='Managers')
        ct_transaction = ContentType.objects.get_for_model(TransactionHistory)
        perm_add = Permission.objects.get(codename='add_transactionhistory', content_type=ct_transaction)
        perm_view = Permission.objects.get(codename='view_transactionhistory', content_type=ct_transaction)
        perm_change = Permission.objects.get(codename='change_transactionhistory', content_type=ct_transaction)
        perm_delete = Permission.objects.get(codename='delete_transactionhistory', content_type=ct_transaction)
        caissiers_group.permissions.add(perm_view, perm_add)
        managers_group.permissions.add(perm_view, perm_add, perm_change, perm_delete)

        self.stdout.write(self.style.SUCCESS("Les groupes 'Caissiers' et 'Managers' ont été configurés avec succès !"))