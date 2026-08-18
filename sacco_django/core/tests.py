from decimal import Decimal
from django.test import TestCase
from django.utils import timezone
from .models import Membres, TransactionHistory


class TransactionHistoryModelTest(TestCase):

    def setUp(self):
        # Création d'un membre de test requis pour la relation ForeignKey
        self.membre = Membres.objects.create(
            nom="TestNom",
            prenom="TestPrenom",
            telephone="60000000",
            solde_epargne=10000.0
        )

    def test_create_transaction(self):
        """Vérifie qu'une transaction peut être créée et liée à un membre."""
        transaction = TransactionHistory.objects.create(
            membre=self.membre,
            montant=Decimal('5000.00'),
            type_operation='DEPOT',
            statut='ACTIF',
            description='Versement épargne hebdomadaire'
        )

        self.assertEqual(transaction.montant, Decimal('5000.00'))
        self.assertEqual(transaction.type_operation, 'DEPOT')
        self.assertEqual(transaction.membre, self.membre)
        self.assertEqual(str(transaction), f"DEPOT - {self.membre.nom} {self.membre.prenom} - 5000.00 BIF")

    def test_transaction_default_values(self):
        """Vérifie les valeurs par défaut lors de la création d'une transaction."""
        transaction = TransactionHistory.objects.create(
            membre=self.membre,
            montant=Decimal('1500.00')
        )

        self.assertEqual(transaction.type_operation, 'DEPOT')
        self.assertEqual(transaction.statut, 'ACTIF')
        self.assertIsNotNone(transaction.date_transaction)