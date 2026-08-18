import os
import shutil
from datetime import datetime
from django.core.management.base import BaseCommand
from django.conf import settings


class Command(BaseCommand):
    help = 'Crée une sauvegarde automatisée de la base de données SQLite'

    def handle(self, *args, **kwargs):
        db_settings = settings.DATABASES['default']
        if db_settings['ENGINE'] != 'django.db.backends.sqlite3':
            self.stdout.write(self.style.WARNING("Ce script est configuré pour SQLite."))
            return

        db_path = db_settings['NAME']
        backup_dir = os.path.join(settings.BASE_DIR, 'backups')
        os.makedirs(backup_dir, exist_ok=True)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_filename = f"db_backup_{timestamp}.sqlite3"
        backup_path = os.path.join(backup_dir, backup_filename)

        try:
            shutil.copy2(db_path, backup_path)
            self.stdout.write(self.style.SUCCESS(f"Sauvegarde réussie : {backup_path}"))
        except Exception as e:
            self.stdout.write(self.style.ERROR(f"Erreur lors de la sauvegarde : {e}"))