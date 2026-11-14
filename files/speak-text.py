"""Prepares a reply for speech: reads the Stop hook JSON on stdin, prints the language ("en" or "de") on the
first line, then the text to speak, one chunk per line. Prints nothing when there is nothing to say."""
import sys, json, re

# Common words that exist in only one of the two languages (ambiguous ones like "die", "was", "so", "in" are left out).
DE = set("der das und nicht ist ich du wir ein eine einen einem mit für auf dem den von zu auch aber wenn oder wie es sich "
         "im aus bei nach noch nur dass kann wird sind habe hast haben ja nein ihr sie mir mich dir dich uns euch "
         "wurde werden doch schon sehr mein dein kein keine hier dann denn weil".split())
EN = set("the and of to is you that it for with this are not have be on as but we if or can at from they there "
         "would should could your my our their been has had does did just".split())

def language(text):
    """German only on clear evidence (3+ hits and twice the English ones), otherwise English: a wrong German
    voice on English text is worse than the English voice on a short or mixed one."""
    words = re.findall(r"[a-zäöüß]+", text.lower())
    de = sum(w in DE or bool(re.search(r"[äöüß]", w)) for w in words)
    en = sum(w in EN for w in words)
    return "de" if de >= 3 and de >= 2 * en else "en"

# Abbreviations: their dot reads as a sentence end ("Mr. <pause> Bennett") and splits chunks.
ABBR = {
    "en": (("Mr", "Mister"), ("Mrs", "Missus"), ("Ms", "Miss"), ("Dr", "Doctor"), ("Prof", "Professor"),
           ("vs", "versus"), ("e.g", "for example"), ("i.e", "that is"), ("etc", "etcetera")),
    "de": (("Dr", "Doktor"), ("Prof", "Professor"), ("Nr", "Nummer"), ("bzw", "beziehungsweise"), ("ca", "circa"),
           ("usw", "und so weiter"), ("z. ?B", "zum Beispiel"), ("d. ?h", "das heißt")),
}
CODE = {"en": " code omitted. ", "de": " Code ausgelassen. "}

def prepare(m):
    m = re.sub(r"```.*?```", "\0", m, flags=re.S)
    m = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", m)
    m = re.sub(r"[`#*_>|]", "", m)
    lang = language(m)
    m = m.replace("\0", CODE[lang])
    for a, b in ABBR[lang]:
        m = re.sub(r"\b" + (a if " ?" in a else re.escape(a)) + r"\.", b, m)
    # Chunks of whole sentences with doubling target length (100, 200, 400 chars...): each chunk is synthesized
    # while the previous one plays, and is short enough (synthesis ~3x faster than speech) to be ready in time.
    t = re.sub(r"\s+", " ", re.sub(r"\s*\n\s*\n\s*", "| ", m)).strip()  # "|" = paragraph break
    out, size = [], 100
    while t:
        n = next((x.end() for x in re.finditer(r"[.!?][\")]*\|?(?= |$)", t) if x.end() >= size), len(t))
        out.append(t[:n].strip())
        t, size = t[n:].strip(), size * 2
    return lang, out

if __name__ == "__main__":
    d = json.load(sys.stdin)
    m = d.get("last_assistant_message") or ""
    if not m:
        try:
            for l in open(d.get("transcript_path", "")):
                e = json.loads(l)
                if e.get("type") == "assistant":
                    t = "".join(c.get("text", "") for c in e["message"]["content"] if c.get("type") == "text")
                    if t: m = t
        except Exception: pass
    lang, chunks = prepare(m)
    if chunks:
        sys.stdout.write(lang + "\n" + "\n".join(chunks))
