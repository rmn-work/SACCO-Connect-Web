import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()

print("Connexion à PostgreSQL local...")

try:
    conn = psycopg2.connect(
        dbname=os.getenv("DB_NAME", "sacco_fintech_master"),
        user=os.getenv("DB_USER", "saccoconnect_rmn"),
        password=os.getenv("DB_PASSWORD", "sacco2026"),
        host=os.getenv("DB_HOST", "127.0.0.1")
    )
    cursor = conn.cursor()

    print("Suppression des anciennes données...")

    cursor.execute("""
        DROP TABLE IF EXISTS 
        groupes, membres, demandes_sociales, logs, prets, presences, 
        historique_epargne, decaissement_social, amendes CASCADE;
    """)

    conn.commit()
    cursor.close()
    conn.close()
    print("✅ Base de données remise à zéro avec succès !")

except Exception as e:
    print(f"❌ Erreur lors de la réinitialisation : {e}")