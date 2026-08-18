from django.contrib import admin
from .models import (
    Membres, Presences, Amendes, DecaissementSocial, DemandesSociales, Groupes, HistoriqueEpargne,
    HistoriqueSocial, JournalPrets, Logs, TransactionHistory, Pret
)

@admin.register(Membres)
class MembresAdmin(admin.ModelAdmin):
    list_display = ('nom', 'prenom', 'telephone', 'role', 'solde_epargne')
    list_filter = ('role', 'is_active', 'groupe_id')
    search_fields = ('nom', 'prenom', 'telephone')

@admin.register(Presences)
class PresencesAdmin(admin.ModelAdmin):
    list_display = ('id', 'membre_id', 'groupe_id')

@admin.register(Amendes)
class AmendesAdmin(admin.ModelAdmin):
    list_display = ('id',)

@admin.register(DecaissementSocial)
class DecaissementSocialAdmin(admin.ModelAdmin):
    list_display = ('id',)

@admin.register(DemandesSociales)
class DemandesSocialesAdmin(admin.ModelAdmin):
    list_display = ('id',)

@admin.register(Groupes)
class GroupesAdmin(admin.ModelAdmin):
    list_display = ('id',)

@admin.register(HistoriqueEpargne)
class HistoriqueEpargneAdmin(admin.ModelAdmin):
    list_display = ('id',)

@admin.register(HistoriqueSocial)
class HistoriqueSocialAdmin(admin.ModelAdmin):
    list_display = ('id',)

@admin.register(JournalPrets)
class JournalPretsAdmin(admin.ModelAdmin):
    list_display = ('id',)

@admin.register(Logs)
class LogsAdmin(admin.ModelAdmin):
    list_display = ('id',)

@admin.register(TransactionHistory)
class TransactionHistoryAdmin(admin.ModelAdmin):
    list_display = ('id', 'membre', 'montant', 'type_operation', 'date_transaction')

@admin.register(Pret)
class PretAdmin(admin.ModelAdmin):
    list_display = ('id', 'membre', 'montant', 'statut', 'date_demande')
    list_filter = ('statut', 'date_demande')
    search_fields = ('membre__nom', 'membre__prenom')