def send_member_notification(membre, message_content):
    telephone = membre.telephone
    if not telephone:
        return False

    print(f"[NOTIFICATION SMS] Envoi au {telephone} : {message_content}")
    return True


def calculer_amortissement(montant, taux_annuel, duree_mois=3):
    taux_mensuel = (taux_annuel / 100) / 12
    if taux_mensuel == 0:
        mensualite = montant / duree_mois
    else:
        mensualite = montant * (taux_mensuel * (1 + taux_mensuel) ** duree_mois) / (
                    (1 + taux_mensuel) ** duree_mois - 1)

    tableau = []
    reste_du = montant
    for i in range(1, duree_mois + 1):
        interet = reste_du * taux_mensuel
        principal = mensualite - interet
        reste_du -= principal
        tableau.append({
            'mois': i,
            'mensualite': round(mensualite, 2),
            'interet': round(interet, 2),
            'principal': round(principal, 2),
            'reste': max(0, round(reste_du, 2))
        })
    return tableau