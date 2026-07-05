import os
import hashlib
from datetime import datetime, date
import pytz
import requests
from bs4 import BeautifulSoup
import qrcode
from fpdf import FPDF
import psycopg2
from psycopg2.extensions import register_adapter, AsIs
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, status, Query, Request, Depends, APIRouter, UploadFile, File
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict
from fastapi.security import OAuth2PasswordRequestForm, OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from datetime import timedelta
import hashlib


# Configuration de sécurité
SECRET_KEY = os.getenv("JWT_SECRET", "une_cle_tres_longue_et_secrete_a_changer_en_production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # Expiration dans 7 jours (pratique pour le mobile)

# Gestionnaire de mots de passe (Remplace hashlib)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Définition du schéma de sécurité (FastAPI va chercher le token ici)
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

# ==========================================================
# 1. CONFIGURATION INITIALE
# ==========================================================
load_dotenv()
register_adapter(AsIs, AsIs)

app = FastAPI(
    title="SACCO Connect Burundi",
    description="Back-end unifié pour l'application mobile et l'interface de la SACCO FinTech",
    version="1.1.0"
)

# Ajout du Middleware CORS pour autoriser le futur site web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Pour l'instant on autorise tout. On mettra l'URL exacte du site Web Render plus tard.
    allow_credentials=True,
    allow_methods=["*"],  # Autorise les requêtes POST (login), GET, etc.
    allow_headers=["*"],  # Autorise tous les headers (notamment pour les tokens d'authentification)
)

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")

if DATABASE_URL:
    if DATABASE_URL.startswith("postgres://"):
        DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)
    db_conn_string = DATABASE_URL
else:
    db_conn_string = f"postgresql://{os.getenv('DB_USER', 'Sacco')}:{os.getenv('DB_PASSWORD', 'sacco2026')}@{os.getenv('DB_HOST', '127.0.0.1')}:{os.getenv('DB_PORT', '5432')}/{os.getenv('DB_NAME', 'sacco_fintech_master')}"

db_conn = psycopg2.connect(db_conn_string)
engine = create_engine(db_conn_string)


# DB_CONFIG = {
#     "dbname": os.getenv("DB_NAME", "sacco_fintech_master"),
#     "user": os.getenv("DB_USER", "Sacco"),
#     "password": os.getenv("DB_PASSWORD", "sacco2026"),
#     "host": os.getenv("DB_HOST", "127.0.0.1"),
#     "port": os.getenv("DB_PORT", "5432")
# }

if os.path.exists("./static"):
    os.makedirs("./static/documents", exist_ok=True)
    app.mount("/documents", StaticFiles(directory="./static/documents"), name="documents")

# ==========================================================
# 2. DEPENDANCES DE BASE DE DONNEES UNIFIEES
# ==========================================================
def get_db_cursor():
    conn = psycopg2.connect(db_conn_string)
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    try:
        yield cursor
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        cursor.close()
        conn.close()

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


def get_current_user(token: str = Depends(oauth2_scheme), cursor=Depends(get_db_cursor)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token invalide")
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token invalide ou expiré")

    cursor.execute("SELECT * FROM membres WHERE id = %s", (user_id,))
    user = cursor.fetchone()
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Utilisateur introuvable")
    return user

# ==========================================================
# 3. MODELES PYDANTIC
# ==========================================================
class LoginRequest(BaseModel):
    telephone: str
    pin: str

class InscriptionPayload(BaseModel):
    nom: str
    prenom: str
    age: int
    sexe: str
    telephone: str
    cni: str
    colline: str
    quartier: str
    avenue: str
    maison: str

# --- GESTION DES GROUPES & MEMBRES ---
class GroupeCreate(BaseModel):
    nom_groupe: str
    president_nom: str
    secretaire_nom: str

class GroupSettingsRequest(BaseModel):
    date_reunion_prochaine: date
    montant_hebdo: int

class MembreUpdate(BaseModel):
    role: str
    groupe_id: int
    admin_nom: str

# --- SAISIES HEBDOMADAIRES (Fusionnées) ---
class MembreSaisieInput(BaseModel):
    membre_id: int
    presence: str  # "P" ou "A"
    epargne: float
    caisse_sociale: float
    amende: bool

class SaisieHebdomadaireRequest(BaseModel):
    date_reunion: date
    date_prochaine_reunion: date
    enregistre_par: str
    enregistrements: List[MembreSaisieInput]

# --- DEMANDES & PRÊTS ---
class DemandeSocialeInput(BaseModel):
    montant_demande: int
    motif: str

class DemandePretInput(BaseModel):
    montant: int
    motif: str
    taux_interet_applique: float = 5.0

class ValidationPretSchema(BaseModel):
    approuver: bool
    admin_id: int

class PenaliteSchema(BaseModel):
    taux_penalite_mensuel: float
    admin_id: int
    mois_retard: int

# --- CONFIGURATION / COTISATIONS (Fusionnées) ---
class CotisationUpdateRequest(BaseModel):
    nouveau_montant: int
    admin_id: int

# ==========================================================
# 4. FONCTIONS UTILITAIRES ET LOGS
# ==========================================================
def log_audit_api(user: str, action: str, details: str):
    conn = psycopg2.connect(**DB_CONFIG)
    cursor = conn.cursor()
    try:
        cursor.execute(
            "INSERT INTO logs (utilisateur, action, details, date_action) VALUES (%s, %s, %s, %s)",
            (user, action, details, datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        )
        conn.commit()
    except Exception as e:
        print(f"⚠️ Échec du log d'audit : {e}")
    finally:
        cursor.close()
        conn.close()

# class SaccoPDF(FPDF):
#     def __init__(self):
#         super().__init__(orientation='P', unit='mm', format='A4')
#         self.alias_nb_pages()
#
#     def header(self):
#         logo_path = "SACCO Connect.png"
#         if os.path.exists(logo_path):
#             self.image(logo_path, 10, 8, 30)
#         self.set_font("Arial", "B", 12)
#         self.set_text_color(44, 62, 80)
#         self.cell(0, 5, "SACCO FinTech BURUNDI", align="R", new_x="LMARGIN", new_y="NEXT")
#         self.set_font("Arial", "", 10)
#         self.cell(0, 5, "Service d'Épargne et de Crédit", align="R", new_x="LMARGIN", new_y="NEXT")
#         self.cell(0, 5, f"Date: {datetime.now().strftime('%d/%m/%Y')}", align="R", new_x="LMARGIN", new_y="NEXT")
#         self.ln(20)
#         self.set_draw_color(44, 62, 80)
#         self.line(10, 35, 200, 35)
#
#     def footer(self):
#         self.set_y(-15)
#         self.set_font("Arial", "I", 8)
#         self.set_text_color(128, 128, 128)
#         self.cell(0, 10, f"Page {self.page_no()}/{{nb}} - Document Officiel Sacco FinTech", align="C")


# ==========================================================
# 5. INITIALISATION SYSTEME (Startup)
# ==========================================================
@app.on_event("startup")
def startup_db_setup():
    print("🚀 Initialisation de la base de données PostgreSQL (init_db)...")

    try:
        local_conn = psycopg2.connect(db_conn_string)
        cursor = local_conn.cursor()

        # Table Groupes (Uniformisation du nom de la cotisation : montant_hebdo)
        cursor.execute('''CREATE TABLE IF NOT EXISTS groupes 
            (id SERIAL PRIMARY KEY, nom_groupe TEXT, president_id INTEGER, 
            secretaire_id INTEGER, montant_hebdo REAL DEFAULT 5000, date_reunion_derniere TEXT, date_reunion_prochaine TEXT, 
            taux_amende REAL DEFAULT 1000, is_active INTEGER DEFAULT 1)''')

        # Table Membres
        cursor.execute('''CREATE TABLE IF NOT EXISTS membres 
            (id SERIAL PRIMARY KEY, nom TEXT, prenom TEXT, age INTEGER, sexe TEXT,
            telephone TEXT UNIQUE, cni TEXT, colline TEXT, quartier TEXT, avenue TEXT, maison TEXT,
            pin TEXT, role TEXT, groupe_id INTEGER, doit_changer_pin INTEGER DEFAULT 0,
            solde_epargne REAL DEFAULT 0, solde_pret REAL DEFAULT 0, is_active INTEGER DEFAULT 1,
            caisse_sociale REAL DEFAULT 0, last_login TEXT, status_presence TEXT DEFAULT 'A',
            credit_en_cours REAL DEFAULT 0, credit_rembourse REAL DEFAULT 0, 
            credit_restant REAL DEFAULT 0, solde_pret_social REAL DEFAULT 0)''')

        cursor.execute('''CREATE TABLE IF NOT EXISTS demandes_sociales 
            (id SERIAL PRIMARY KEY, membre_id INTEGER, montant_demande REAL, motif TEXT, status TEXT DEFAULT 'En attente', date_demande TEXT)''')

        cursor.execute('''CREATE TABLE IF NOT EXISTS logs 
            (id SERIAL PRIMARY KEY, utilisateur TEXT, action TEXT, details TEXT, date TEXT)''')

        cursor.execute('''CREATE TABLE IF NOT EXISTS prets 
            (id SERIAL PRIMARY KEY, membre_id INTEGER, montant REAL, motif TEXT, reste_a_payer REAL, status TEXT, 
            date_demande TEXT, autorise_par TEXT, date_validation TEXT, taux_interet_applique REAL DEFAULT 5.0)''')

        cursor.execute('''CREATE TABLE IF NOT EXISTS presences 
            (id SERIAL PRIMARY KEY, membre_id INTEGER, groupe_id INTEGER, date_reunion TEXT, status TEXT DEFAULT 'A')''')

        # Table historique_epargne corrigée pour correspondre aux insertions
        cursor.execute('''CREATE TABLE IF NOT EXISTS historique_epargne (id SERIAL PRIMARY KEY, membre_id INTEGER, 
            groupe_id INTEGER, montant REAL DEFAULT 0, montant_epargne REAL DEFAULT 0, montant_social REAL DEFAULT 0, date_reunion TEXT, 
            heure_enregistrement TEXT, enregistre_par TEXT, FOREIGN KEY(membre_id) REFERENCES membres(id))''')

        cursor.execute("""CREATE TABLE IF NOT EXISTS decaissement_social (id SERIAL PRIMARY KEY, groupe_id INTEGER, membre_id INTEGER,
            objet TEXT, date_decaissement TEXT, montant_decaisse REAL DEFAULT 0.0, montant_rembourse REAL DEFAULT 0.0, enregistre_par TEXT,
            heure_enregistrement TEXT, FOREIGN KEY(membre_id) REFERENCES membres(id))""")

        cursor.execute("""CREATE TABLE IF NOT EXISTS amendes (id SERIAL PRIMARY KEY, groupe_id INTEGER, membre_id INTEGER, motif TEXT,
            montant_a_payer REAL DEFAULT 0.0, montant_paye REAL DEFAULT 0.0, date_enregistrement TEXT, enregistre_par TEXT,
            FOREIGN KEY(membre_id) REFERENCES membres(id))""")

        # Migration dynamique si colonnes manquantes dans groupes
        cursor.execute("SELECT column_name FROM information_schema.columns WHERE table_name = 'groupes'")
        columns_grp = [row[0] for row in cursor.fetchall()]
        if 'is_active' not in columns_grp:
            cursor.execute("ALTER TABLE groupes ADD COLUMN is_active INTEGER DEFAULT 1")
        if 'date_reunion_derniere' not in columns_grp:
            cursor.execute("ALTER TABLE groupes ADD COLUMN date_reunion_derniere TEXT")
        if 'date_reunion_prochaine' not in columns_grp:
            cursor.execute("ALTER TABLE groupes ADD COLUMN date_reunion_prochaine TEXT")

        # Insertion groupe par défaut
        cursor.execute("SELECT COUNT(*) FROM groupes WHERE id = 1")
        if cursor.fetchone()[0] == 0:
            cursor.execute(
                "INSERT INTO groupes (id, nom_groupe, montant_hebdo, is_active) VALUES (1, 'Groupe Alpha', 5000, 1)")

        pin_standard_hash = pwd_context.hash("1234")
        mot_de_passe = "tanganyika25"[:72]
        pin_admin_hash = pwd_context.hash(mot_de_passe)

        comptes_test = [
            {"nom": "ADMIN", "prenom": "Système", "telephone": "tanganyika", "role": "admin_sys", "pin": pin_admin_hash,
             "groupe_id": None},
            {"nom": "MEMBRE", "prenom": "Raphael", "telephone": "0000", "role": "membre", "pin": pin_standard_hash,
             "groupe_id": 1},
            {"nom": "PRÉSIDENT", "prenom": "Test", "telephone": "1111", "role": "president", "pin": pin_standard_hash,
             "groupe_id": 1},
            {"nom": "SECRÉTAIRE", "prenom": "Test", "telephone": "2222", "role": "secretaire", "pin": pin_standard_hash,
             "groupe_id": 1}
        ]

        for c in comptes_test:
            cursor.execute("""
                        INSERT INTO membres (nom, prenom, telephone, pin, role, groupe_id, is_active, doit_changer_pin)
                        VALUES (%s, %s, %s, %s, %s, %s, 1, 0)
                        ON CONFLICT (telephone) 
                        DO UPDATE SET pin = EXCLUDED.pin, role = EXCLUDED.role, groupe_id = EXCLUDED.groupe_id, is_active = 1
                    """, (c['nom'], c['prenom'], c['telephone'], c['pin'], c['role'], c['groupe_id']))

        local_conn.commit()
        cursor.close()
        local_conn.close()
        print("✅ Base de données initialisée et compte Administrateur Système configuré.")
    except Exception as e:
        print(f"❌ Erreur critique lors de l'initialisation de la base : {e}")


# ==========================================================
# 6. ENDPOINTS GLOBAUX & AUTHENTIFICATION
# ==========================================================
@app.get('/')
def read_root():
    return {
        "status": "En ligne",
        "projet": "SACCO Connect",
        "database": "Connectée avec succès ✅"
    }


@app.post("/auth/login")
def login(form_data: OAuth2PasswordRequestForm = Depends(), cursor=Depends(get_db_cursor)):
    cursor.execute("SELECT * FROM membres WHERE telephone=%s", (form_data.username,))
    user_data = cursor.fetchone()
    hashed_password_attempt = hashlib.sha256(form_data.password.encode()).hexdigest()

    if not user_data or hashed_password_attempt != user_data['pin']:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Identifiants incorrects.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if user_data.get('is_active') == 0:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Ce compte est archivé ou bloqué."
        )

    heure_connexion = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    cursor.execute("UPDATE membres SET last_login = %s WHERE id = %s", (heure_connexion, user_data['id']))

    access_token = create_access_token(
        data={"sub": str(user_data['id']), "role": user_data['role']}
    )
    return {"access_token": access_token, "token_type": "bearer", "role": user_data['role']}


@app.post("/auth/inscription")
def inscription(data: InscriptionPayload, cursor=Depends(get_db_cursor)):
    hp = pwd_context.hash("1234")
    try:
        cursor.execute(
            """INSERT INTO membres (nom, prenom, age, sexe, telephone, cni, pin, role, is_active, colline, quartier, avenue, maison) 
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s, 1, %s, %s, %s, %s)""",
            (data.nom, data.prenom, data.age, data.sexe, data.telephone, data.cni, hp, 'membre',
             data.colline, data.quartier, data.avenue, data.maison)
        )
        return {"status": "success", "message": "✅ Inscription réussie !"}
    except psycopg2.IntegrityError:
        raise HTTPException(status_code=400, detail="Ce numéro de téléphone est déjà utilisé.")


# ==========================================================
# 7. DASHBOARD ET GESTION DU PROFIL
# ==========================================================
@app.get('/membres/{membre_id}/dashboard')
def get_membre_dashboard(
        membre_id: int,
        current_user: dict = Depends(get_current_user),
        cursor=Depends(get_db_cursor)
):
    if current_user['id'] != membre_id and current_user['role'] not in ['admin', 'admin_sys']:
        raise HTTPException(status_code=403, detail="Accès non autorisé à ce profil.")

    cursor.execute("SELECT * FROM membres WHERE id = %s", (membre_id,))
    membre = cursor.fetchone()

    if not membre:
        raise HTTPException(status_code=404, detail="Membre introuvable.")

    cursor.execute("""
        SELECT g.montant_hebdo 
        FROM membres m
        JOIN groupes g ON m.groupe_id = g.id
        WHERE m.id = %s
    """, (membre_id,))
    groupe_data = cursor.fetchone()
    cotisation_fixee = groupe_data['montant_hebdo'] if groupe_data else 0

    return {
        "solde_epargne": membre.get("solde_epargne", 0),
        "caisse_sociale": membre.get("caisse_sociale", 0),
        "solde_pret": membre.get("solde_pret", 0),
        "encours_credit": membre.get("credit_en_cours", 0),
        "credit_restant": membre.get("credit_restant", 0),
        "status_presence": membre.get("status_presence", "A"),
        "cotisation_hebdo_fixee": cotisation_fixee,
        "devise": "BIF"
    }


@app.get('/membres/{membre_id}/previsions-ia')
def get_previsions_ia(
        membre_id: int,
        current_user: dict = Depends(get_current_user),
        cursor=Depends(get_db_cursor)
):
    if current_user['id'] != membre_id and current_user['role'] not in ['admin', 'admin_sys']:
        raise HTTPException(status_code=403, detail="Accès non autorisé à ces prévisions.")

    cursor.execute("SELECT solde_epargne, credit_restant, groupe_id FROM membres WHERE id = %s", (membre_id,))
    membre = cursor.fetchone()
    if not membre:
        raise HTTPException(status_code=404, detail="Membre introuvable.")
    cursor.execute(
        "SELECT status FROM presences WHERE membre_id = %s ORDER BY id DESC LIMIT 10",
        (membre_id,)
    )

    presences = cursor.fetchall()
    total_reunions = len(presences)
    jours_presents = sum(1 for p in presences if p['status'] == 'P')
    taux_presence = (jours_presents / total_reunions) if total_reunions > 0 else 1.0

    cursor.execute(
        "SELECT montant_epargne FROM historique_epargne WHERE membre_id = %s ORDER BY date_reunion DESC LIMIT 12",
        (membre_id,)
    )
    historique = cursor.fetchall()

    if historique:
        total_poids = 0
        somme_ponderee = 0
        for index, row in enumerate(historique):
            poids = len(historique) - index
            somme_ponderee += row['montant_epargne'] * poids
            total_poids += poids

        moyenne_ponderee_hebdo = somme_ponderee / total_poids
        pred_epargne_mensuelle = moyenne_ponderee_hebdo * 4 * taux_presence
    else:
        cursor.execute("SELECT montant_hebdo FROM groupes WHERE id = %s", (membre['groupe_id'],))
        groupe = cursor.fetchone()
        montant_base = groupe['montant_hebdo'] if groupe else 5000
        pred_epargne_mensuelle = montant_base * 4
    solde_epargne = float(membre['solde_epargne'] or 0)
    credit_restant = float(membre['credit_restant'] or 0)

    capacite_theorique = solde_epargne * 3
    capacite_reelle_estimee = (capacite_theorique * taux_presence) - credit_restant
    capacite_reelle_estimee = max(0.0, capacite_reelle_estimee)

    score_endettement = 50 if capacite_theorique == 0 else (1 - min(1.0,
                                                                    credit_restant / max(1.0, capacite_theorique))) * 50
    score_sante = (taux_presence * 50) + score_endettement

    return {
        "prediction_epargne_mensuelle": round(pred_epargne_mensuelle, 2),
        "capacite_credit_estimee": round(capacite_reelle_estimee, 2),
        "taux_assiduite_pourcent": round(taux_presence * 100, 1),
        "score_credit_scoring": round(score_sante, 1),
        "devise": "BIF"
    }


@app.post("/upload-pdf/")
async def upload_pdf(file: UploadFile = File(...)):
    return {"filename": file.filename}


@app.get('/membres/{membre_id}/historique/')
def get_historique_epargne(membre_id: int, cursor=Depends(get_db_cursor)):
    query = """
        SELECT date_reunion, heure_enregistrement, montant_epargne, montant_social 
        FROM historique_epargne 
        WHERE membre_id = %s 
        ORDER BY date_reunion DESC, heure_enregistrement DESC
    """
    cursor.execute(query, (membre_id,))
    return cursor.fetchall()


# ==========================================================
# 8. DEMANDES SOCIALES ET CRÉDITS
# ==========================================================
@app.post('/membres/{membre_id}/demande-sociale')
def create_demande_sociale(membre_id: int, data: DemandeSocialeInput, cursor=Depends(get_db_cursor)):
    if data.montant_demande <= 0:
        raise HTTPException(status_code=400, detail="Le montant doit être supérieur à 0 BIF.")
    cursor.execute("SELECT id FROM membres WHERE id = %s", (membre_id,))
    if not cursor.fetchone():
        raise HTTPException(status_code=404, detail="Membre introuvable.")
    date_actuelle = datetime.now().strftime("%Y-%m-%d")
    cursor.execute(
        "INSERT INTO demandes_sociales (membre_id, montant_demande, motif, date_demande) VALUES (%s, %s, %s, %s)",
        (membre_id, data.montant_demande, data.motif, date_actuelle)
    )
    return {"status": "success", "message": "✅ Demande de secours social envoyée."}


@app.get('/membres/{membre_id}/mes-demandes-prets')
def get_mes_demandes_prets(membre_id: int, cursor=Depends(get_db_cursor)):
    cursor.execute("SELECT id, montant, motif, status, date_demande FROM prets WHERE membre_id = %s ORDER BY id DESC",
                   (membre_id,))
    return {"data": cursor.fetchall()}


@app.post('/membres/{membre_id}/demande-credit')
def create_demande_credit(membre_id: int, data: DemandePretInput, cursor=Depends(get_db_cursor)):
    if data.montant <= 0:
        raise HTTPException(status_code=400, detail="Le montant doit être > 0.")
    cursor.execute("SELECT solde_epargne FROM membres WHERE id = %s", (membre_id,))
    membre = cursor.fetchone()
    if not membre:
        raise HTTPException(status_code=404, detail="Membre introuvable.")
    max_loan = int(membre['solde_epargne'] * 3)
    if data.montant > max_loan:
        raise HTTPException(status_code=400, detail=f"Maximum autorisé : {max_loan} BIF.")
    cursor.execute(
        """INSERT INTO prets (membre_id, montant, motif, reste_a_payer, status, date_demande, taux_interet_applique) 
           VALUES (%s, %s, %s, %s, 'EN ATTENTE', %s, %s)""",
        (membre_id, data.montant, data.motif, data.montant, datetime.now().strftime("%Y-%m-%d"),
         data.taux_interet_applique)
    )
    return {"status": "success", "message": "✅ Demande transmise avec taux personnalisé."}

@app.post("/api/credits/{credit_id}/appliquer-penalite")
def appliquer_penalite(credit_id: int, payload: PenaliteSchema, cursor=Depends(get_db_cursor)):
    cursor.execute("SELECT role FROM membres WHERE id = %s", (payload.admin_id,))
    admin = cursor.fetchone()
    if not admin or admin['role'].lower() not in ["president", "secretaire", "admin", "admin_sys"]:
        raise HTTPException(status_code=403, detail="Droits insuffisants.")

    cursor.execute("SELECT * FROM prets WHERE id = %s", (credit_id,))
    credit = cursor.fetchone()
    if not credit:
        raise HTTPException(status_code=404, detail="Crédit introuvable.")

    penalite_totale = float(credit['reste_a_payer']) * (payload.taux_penalite_mensuel / 100.0) * payload.mois_retard
    cursor.execute("UPDATE prets SET reste_a_payer = reste_a_payer + %s WHERE id = %s", (penalite_totale, credit_id))
    cursor.execute(
        "UPDATE membres SET solde_pret = solde_pret + %s, credit_restant = credit_restant + %s WHERE id = %s",
        (penalite_totale, penalite_totale, credit['membre_id']))

    return {"status": "success", "message": f"Pénalité de {penalite_totale} BIF appliquée."}

# ==========================================================
# 9. GESTION DES REUNIONS & SAISIES HEBDOMADAIRES (UNIFIÉ)
# ==========================================================
@app.get("/membres/actifs/{groupe_id}")
def get_active_members(groupe_id: int, role: str = Query(...), cursor=Depends(get_db_cursor)):
    if role == "admin_sys":
        cursor.execute("SELECT id, nom, prenom, telephone, solde_epargne, solde_pret FROM membres WHERE is_active = 1")
    else:
        cursor.execute(
            "SELECT id, nom, prenom, telephone, solde_epargne, solde_pret FROM membres WHERE groupe_id = %s AND is_active = 1",
            (groupe_id,))
    return cursor.fetchall()


@app.get("/groupes/{group_id}/membres-formater")
def get_membres_groupe_pour_flutter(group_id: int, cursor=Depends(get_db_cursor)):
    cursor.execute("SELECT id, nom, prenom FROM membres WHERE groupe_id = %s AND is_active = 1 ORDER BY nom ASC",
                   (group_id,))
    rows = cursor.fetchall()
    return [{
        "id": row['id'],
        "nom": f"{row['nom']} {row['prenom']}",
        "presence": "P",
        "epargne": 0.0,
        "caisse": 0.0,
        "amende": False
    } for row in rows]


@app.post('/groupes/{groupe_id}/saisie-hebdo')
def submit_saisie_hebdo(groupe_id: int, data: SaisieHebdomadaireRequest, cursor=Depends(get_db_cursor)):
    cursor.execute("SELECT taux_amende FROM groupes WHERE id = %s", (groupe_id,))
    groupe = cursor.fetchone()
    taux_amende = groupe.get('taux_amende', 0) if groupe else 0
    heure_actuelle = datetime.now().strftime("%H:%M:%S")
    for saisie in data.saisies:
        amende_appliquee = taux_amende if saisie.amende else 0
        final_epargne = max(0, float(saisie.epargne - amende_appliquee))
        final_social = float(saisie.social)
        cursor.execute("""
            UPDATE membres 
            SET solde_epargne = solde_epargne + %s, caisse_sociale = caisse_sociale + %s, status_presence = %s 
            WHERE id = %s
        """, (final_epargne, final_social, saisie.presence, saisie.id))
        cursor.execute("""
            INSERT INTO historique_epargne (membre_id, groupe_id, date_reunion, heure_enregistrement, montant_epargne, montant_social, enregistre_par) 
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (saisie.id, groupe_id, data.date_reunion_actuelle, heure_actuelle, final_epargne, final_social,
              data.enregistre_par))

    # Mise à jour des dates du groupe
    cursor.execute("UPDATE groupes SET date_reunion_derniere = %s, date_reunion_prochaine = %s WHERE id = %s",
                   (data.date_reunion_actuelle, data.date_reunion_prochaine, groupe_id))

    return {"status": "success", "message": "✅ Réunion et saisies enregistrées avec succès !"}

# ==========================================================
# 10. ADMINISTRATION BUREAU EXECUTIF
# ==========================================================
@app.get('/admin/prets-en-attente')
def get_prets_en_attente(cursor=Depends(get_db_cursor)):
    query = """
        SELECT id, montant, motif, date_demande, 'CREDIT' as type_pret, membre_id 
        FROM prets WHERE UPPER(status) = 'EN ATTENTE'
        UNION ALL
        SELECT id, montant_demande as montant, motif, date_demande, 'SOCIAL' as type_pret, membre_id 
        FROM demandes_sociales WHERE UPPER(status) = 'EN ATTENTE'
        ORDER BY date_demande DESC
    """
    cursor.execute(query)
    data = cursor.fetchall()

    for row in data:
        cursor.execute("SELECT nom, prenom, telephone FROM membres WHERE id = %s", (row['membre_id'],))
        membre = cursor.fetchone()
        row['nom'] = membre['nom'] if membre else "Inconnu"
        row['prenom'] = membre['prenom'] if membre else ""
        row['telephone'] = membre['telephone'] if membre else ""

    return {"status": "success", "data": data}


@app.post('/admin/valider-demande')
def valider_demande(payload: dict, cursor=Depends(get_db_cursor)):
    admin_id = payload.get('admin_id')
    cursor.execute("SELECT role FROM membres WHERE id = %s", (admin_id,))
    admin = cursor.fetchone()

    if not admin or admin['role'].lower() not in ["president", "secretaire", "admin", "admin_sys"]:
        raise HTTPException(status_code=403, detail="Non autorisé.")

    id_demande = payload.get('id')
    type_demande = payload.get('type')  # 'CREDIT' ou 'SOCIAL'
    approuver = payload.get('approuver')

    table = "prets" if type_demande == "CREDIT" else "demandes_sociales"
    statut = "APPROUVÉ" if approuver else "REJETÉ"
    date_validation = datetime.now().strftime("%Y-%m-%d")

    if type_demande == "CREDIT":
        cursor.execute(
            f"UPDATE {table} SET status = %s, date_validation = %s WHERE id = %s RETURNING membre_id, montant",
            (statut, date_validation, id_demande))
        pret = cursor.fetchone()
        if approuver and pret:
            cursor.execute("""
                UPDATE membres 
                SET credit_en_cours = credit_en_cours + %s, 
                    credit_restant = credit_restant + %s 
                WHERE id = %s
            """, (pret['montant'], pret['montant'], pret['membre_id']))
    else:
        cursor.execute(f"UPDATE {table} SET status = %s WHERE id = %s", (statut, id_demande))
        if approuver:
            cursor.execute("SELECT membre_id, montant_demande FROM demandes_sociales WHERE id = %s", (id_demande,))
            demande = cursor.fetchone()
            if demande:
                cursor.execute("UPDATE membres SET caisse_sociale = caisse_sociale - %s WHERE id = %s",
                               (demande['montant_demande'], demande['membre_id']))

    return {"status": "success", "message": f"Demande {statut} avec succès."}


@app.get('/admin/rapports')
def get_rapports_globaux(cursor=Depends(get_db_cursor)):
    cursor.execute("""
        SELECT SUM(solde_epargne) as total_epargne, SUM(caisse_sociale) as total_social, SUM(credit_restant) as total_credits_actifs
        FROM membres WHERE is_active = 1
    """)
    stats = cursor.fetchone()
    return {
        "status": "success",
        "data": {
            "total_epargne": stats['total_epargne'] or 0.0,
            "total_social": stats['total_social'] or 0.0,
            "total_credits_actifs": stats['total_credits_actifs'] or 0.0,
            "penalites_percues": 0.0
        }
    }


@app.get('/admin/credits-en-retard')
def get_credits_retard(cursor=Depends(get_db_cursor)):
    cursor.execute("""
        SELECT p.id, p.reste_a_payer, p.date_validation, m.nom, m.prenom 
        FROM prets p 
        JOIN membres m ON p.membre_id = m.id 
        WHERE p.status = 'APPROUVÉ' AND p.reste_a_payer > 0
    """)
    return {"status": "success", "data": [{
        "id": p['id'],
        "membre": f"{p['nom']} {p['prenom']}",
        "type": "Standard",
        "credit_restant": p['reste_a_payer'],
        "mois_retard": 1
    } for p in cursor.fetchall()]}

@app.put('/groupes/{groupe_id}/modifier-cotisation')
def modifier_cotisation_groupe(groupe_id: int, payload: CotisationUpdateRequest, cursor=Depends(get_db_cursor)):
    cursor.execute("SELECT role, groupe_id FROM membres WHERE id = %s", (payload.admin_id,))
    admin = cursor.fetchone()

    if not admin or admin['role'].lower() not in ['president', 'secretaire', 'admin', 'admin_sys']:
        raise HTTPException(status_code=403, detail="⚠️ Action non autorisée pour votre rôle.")

    if admin['role'].lower() not in ['admin', 'admin_sys'] and admin['groupe_id'] != groupe_id:
        raise HTTPException(status_code=403,
                            detail="❌ Vous ne pouvez modifier que la cotisation de votre propre groupe.")

    if payload.nouveau_montant < 0:
        raise HTTPException(status_code=400, detail="❌ Le montant ne peut pas être négatif.")

    cursor.execute("UPDATE groupes SET montant_hebdo = %s WHERE id = %s", (payload.nouveau_montant, groupe_id))
    return {"status": "success", "message": f"✅ Cotisation du groupe mise à jour à {payload.nouveau_montant} BIF"}