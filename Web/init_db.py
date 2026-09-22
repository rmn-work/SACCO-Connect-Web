import os
import psycopg2
from dotenv import load_dotenv
from passlib.context import CryptContext

load_dotenv()

# Configuration du hachage pour qu'il soit identique à app.py et api.py
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

print("Connexion à PostgreSQL local pour la correction des comptes...")

try:
    conn = psycopg2.connect(
        dbname=os.getenv("DB_NAME", "sacco_fintech_master"),
        user=os.getenv("DB_USER", "saccoconnect_rmn"),
        password=os.getenv("DB_PASSWORD", "sacco2626"),
        host=os.getenv("DB_HOST", "127.0.0.1"),
    )
    cursor = conn.cursor()

    pin_standard_hash = pwd_context.hash("1234")
    pin_admin_hash = pwd_context.hash("SACCO_Bujumbura-BBIN")

    comptes_init = [
        {"nom": "ADMIN", "prenom": "Système", "telephone": "admin", "role": "admin_sys", "pin": pin_admin_hash, "groupe_id": None},
        {"nom": "NKURUNZIZA", "prenom": "Raphael", "telephone": "0000", "role": "membre", "pin": pin_standard_hash, "groupe_id": 1},
        {"nom": "PRESIDENT", "prenom": "Officiel", "telephone": "1111", "role": "president", "pin": pin_standard_hash, "groupe_id": 1},
        {"nom": "SECRETAIRE", "prenom": "Officiel", "telephone": "2222", "role": "secretaire", "pin": pin_standard_hash, "groupe_id": 1}
    ]

    print("Mise à jour des comptes avec les PINs chiffrés...")

    for c in comptes_init:
        cursor.execute("""
            INSERT INTO membres (nom, prenom, telephone, pin, role, groupe_id, is_active, doit_changer_pin)
            VALUES (%s, %s, %s, %s, %s, %s, 1, 0)
            ON CONFLICT (telephone) 
            DO UPDATE SET 
                pin = EXCLUDED.pin, 
                role = EXCLUDED.role, 
                groupe_id = EXCLUDED.groupe_id, 
                is_active = 1,
                doit_changer_pin = 0
        """, (c['nom'], c['prenom'], c['telephone'], c['pin'], c['role'], c['groupe_id']))

    conn.commit()
    cursor.close()
    conn.close()
    print("✅ Tous les comptes testeurs ont été créés/mis à jour avec des PINs hachés (bcrypt) !")

except Exception as e:
    print(f"❌ Erreur : {e}")