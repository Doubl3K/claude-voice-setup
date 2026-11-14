"""Run: python3 -m unittest discover tests  (guards the language choice: a wrong voice makes a reply unintelligible)."""
import os, sys, unittest
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "files"))
import importlib
speak_text = importlib.import_module("speak-text")

class Language(unittest.TestCase):
    def lang(self, text): return speak_text.prepare(text)[0]

    def test_english(self):
        self.assertEqual(self.lang("Done. The first chunk is now sent, and the rest is synthesized while it plays."), "en")
        self.assertEqual(self.lang("Yes."), "en")
        self.assertEqual(self.lang("OK"), "en")

    def test_german(self):
        self.assertEqual(self.lang("Hallo Kevin, das ist ein kurzer Test auf Deutsch. Ich hoffe, du kannst mich verstehen."), "de")
        self.assertEqual(self.lang("Die Straße war nass, aber die Sonne schien über den Bergen."), "de")

    def test_german_with_english_terms(self):
        self.assertEqual(self.lang("Ich habe den Commit gepusht und das Repository ist jetzt auf dem neuesten Stand, der Rest ist nicht nötig."), "de")

    def test_english_with_german_words(self):
        self.assertEqual(self.lang("The word Straße means street, and Danke means thanks, as you can see in the list."), "en")

    def test_code_does_not_decide(self):
        self.assertEqual(self.lang("Here is the fix:\n\n```\ndef der_und_das(ist, nicht, ein): pass\n```\n\nIt is in the file."), "en")

class Text(unittest.TestCase):
    def test_abbreviations_per_language(self):
        self.assertIn("Mister Bennet", speak_text.prepare("My dear Mr. Bennet, it is the one that you know.")[1][0])
        self.assertIn("zum Beispiel", speak_text.prepare("Das ist ein Test, z. B. für das Ende und die Nummer, ich bin hier.")[1][0])

    def test_chunks_grow_and_keep_paragraph_marker(self):
        _, chunks = speak_text.prepare("One sentence here. " * 5 + "\n\n" + "Another sentence follows. " * 30)
        self.assertGreater(len(chunks), 1)
        self.assertTrue(chunks[0].endswith("."))
        self.assertIn("|", "".join(chunks))

    def test_empty(self):
        self.assertEqual(speak_text.prepare("   ")[1], [])

if __name__ == "__main__":
    unittest.main()
