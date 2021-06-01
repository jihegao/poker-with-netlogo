import unittest
from lib.checkers import input_type_checker, card_checker, convert_case, is_list_unique

class TestCheckers(unittest.TestCase):
    """
    Unit tests for checker methods
    """

    def test_valid_input_true(self):
        """
        Checks if the input is a list of len > 2 for board and len == 2 for hand
        :return:
        """

        board = ['As', 'Ac', 'Ad']
        hand = ['Ah', 'Kd']

        self.assertTrue(input_type_checker(board, hand))

    def test_valid_input_false_board_wrong(self):
        """
        Checks if the method can detect wrong input
        :return:
        """

        board = ['As', 'Ac']
        hand = ['Ah', 'Kd']

        self.assertFalse(input_type_checker(board, hand))

    def test_valid_input_false_hand_wrong(self):
        """
        Checks if the method can detect wrong input
        :return:
        """

        board = ['As', 'Ac', 'Ad']
        hand = ['Ah']

        self.assertFalse(input_type_checker(board, hand))


    def test_convert_case(self):
        """
        Checks is casing is properly converted
        :return:
        """

        board = ['aS', 'ad', 'Ac']

        self.assertEqual(['As', 'Ad', 'Ac'],
                         convert_case(board))

    def test_valid_card_true(self):
        """
        Checks if valid cards are passed
        :return:
        """

        list_of_cards = ['aS', 'Ac']

        self.assertTrue(card_checker(list_of_cards))


    def test_valid_card_false(self):
        """
        Checks if invalid cards are caught
        :return:
        """

        list_of_cards = ['Z3', 'Ax']

        self.assertFalse(card_checker(list_of_cards))

    def test_is_list_unique(self):
        """
        Checks if the list is unique
        :return:
        """

        list_1 = [1,2,3,4,5]
        list_2 = [1,2,2,3,3,4,5]
        list_3 = ['Ac', 'Ah', 'Ad', 'As']
        list_4 = ['Ac', 'Ac', 'Ah']

        self.assertTrue(is_list_unique(list_1))
        self.assertTrue(is_list_unique(list_3))
        self.assertFalse(is_list_unique(list_2))
        self.assertFalse(is_list_unique(list_4))


if __name__ == '__main__':
    unittest.main()