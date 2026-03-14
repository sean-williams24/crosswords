"""
Word of the Day Generator
==========================

Generates interesting/unusual words and uploads them to Supabase.

Usage:
    python generate_wotd.py --count 7                  # Generate 7 words
    python generate_wotd.py --date 2026-03-21           # Start from specific date
    python generate_wotd.py --dry-run                   # Generate without uploading

Environment Variables (only needed for upload):
    SUPABASE_URL  — Your Supabase project URL
    SUPABASE_KEY  — Your Supabase service-role key (NOT anon key)
"""

import argparse
import json
import os
import random
import sys
from datetime import date, timedelta

# ── Word Bank ───────────────────────────────────────────────────────────────
# A curated bank of unusual, interesting, and delightful words.
# Each entry matches the WordOfTheDay Swift model.

WORD_BANK = [
    {
        "word": "Apricity",
        "pronunciation": "ah-PRIS-ih-tee",
        "partOfSpeech": "noun",
        "definition": "The warmth of the sun in winter.",
        "etymology": "From Latin 'apricus' (warmed by the sun), derived from 'aperire' (to open). The word fell out of common use after the 17th century.",
        "synonyms": ["winter warmth", "solar warmth"],
        "exampleSentence": "She sat on the bench, basking in the apricity of the February afternoon."
    },
    {
        "word": "Vellichor",
        "pronunciation": "VEL-ih-kor",
        "partOfSpeech": "noun",
        "definition": "The strange wistfulness of used bookshops, which are somehow infused with the passage of time.",
        "etymology": "Coined by John Koenig in 'The Dictionary of Obscure Sorrows', blending 'vellum' (parchment) with a suffix evoking melancholy.",
        "synonyms": ["book nostalgia", "literary wistfulness"],
        "exampleSentence": "A powerful vellichor settled over him as he wandered the dusty shelves of the secondhand bookshop."
    },
    {
        "word": "Phosphene",
        "pronunciation": "FOS-feen",
        "partOfSpeech": "noun",
        "definition": "The ring or spot of light produced by pressure on the eyeball or direct stimulation of the visual system other than by light.",
        "etymology": "From Greek 'phos' (light) and 'phainein' (to show). First used in English in the mid-19th century.",
        "synonyms": ["light flash", "pressure light"],
        "exampleSentence": "When she rubbed her tired eyes, bright phosphenes danced across her vision."
    },
    {
        "word": "Clinomania",
        "pronunciation": "kly-noh-MAY-nee-ah",
        "partOfSpeech": "noun",
        "definition": "An excessive desire to stay in bed.",
        "etymology": "From Greek 'klinein' (to lean or recline) and 'mania' (madness or obsession).",
        "synonyms": ["bed obsession", "sleep compulsion"],
        "exampleSentence": "His clinomania was at its worst on cold Monday mornings."
    },
    {
        "word": "Psithurism",
        "pronunciation": "SITH-yur-iz-um",
        "partOfSpeech": "noun",
        "definition": "The sound of wind rustling through trees and leaves.",
        "etymology": "From Greek 'psithuros' (whispering, slanderous), related to 'psithurizo' (to whisper).",
        "synonyms": ["leaf rustle", "wind whisper"],
        "exampleSentence": "The gentle psithurism of the oak trees was the only sound in the afternoon heat."
    },
    {
        "word": "Aphelion",
        "pronunciation": "ah-FEE-lee-on",
        "partOfSpeech": "noun",
        "definition": "The point in an orbit at which a planet or comet is furthest from the sun.",
        "etymology": "From Greek 'apo' (away from) and 'helios' (sun). First used in English around 1656.",
        "synonyms": ["farthest point", "orbital maximum"],
        "exampleSentence": "Earth reaches its aphelion in early July, when it is about 152 million kilometres from the sun."
    },
    {
        "word": "Eunoia",
        "pronunciation": "yoo-NOY-ah",
        "partOfSpeech": "noun",
        "definition": "Beautiful thinking; a well-disposed mind or goodwill towards others.",
        "etymology": "From Greek 'eu' (well, good) and 'noos' (mind). It is the shortest English word containing all five vowels.",
        "synonyms": ["goodwill", "benevolence", "well-mindedness"],
        "exampleSentence": "The new manager led with genuine eunoia, earning the trust of every team member."
    },
    {
        "word": "Selcouth",
        "pronunciation": "SEL-kooth",
        "partOfSpeech": "adjective",
        "definition": "Unfamiliar, rare, strange, and yet marvellous.",
        "etymology": "From Old English 'selcūþ', combining 'seld' (rare) and 'cūþ' (known). Common in Middle English but now archaic.",
        "synonyms": ["marvellous", "wondrous", "exotic"],
        "exampleSentence": "The aurora borealis was a selcouth sight that left them speechless."
    },
    {
        "word": "Chatoyant",
        "pronunciation": "shah-TOY-ant",
        "partOfSpeech": "adjective",
        "definition": "Having a changeable lustre or colour with an undulating narrow band of white light, like a cat's eye.",
        "etymology": "From French 'chatoyer' (to shimmer like a cat's eye), from 'chat' (cat).",
        "synonyms": ["iridescent", "lustrous", "shimmering"],
        "exampleSentence": "The chatoyant gemstone seemed to glow from within as she turned it in the light."
    },
    {
        "word": "Orenda",
        "pronunciation": "oh-REN-dah",
        "partOfSpeech": "noun",
        "definition": "A mystical force or spiritual power believed to inhabit certain people, animals, or objects.",
        "etymology": "From the Huron-Iroquois language, referring to a supernatural force inherent in all things.",
        "synonyms": ["spiritual power", "mystical force", "life force"],
        "exampleSentence": "The elder spoke of the orenda that connected all living things in the forest."
    },
    {
        "word": "Virga",
        "pronunciation": "VUR-gah",
        "partOfSpeech": "noun",
        "definition": "Wisps of precipitation falling from a cloud but evaporating before reaching the ground.",
        "etymology": "From Latin 'virga' (rod, stripe, streak). Used in meteorology since the 1940s.",
        "synonyms": ["phantom rain", "dry rain"],
        "exampleSentence": "The desert sky was streaked with virga — rain that vanished long before it could quench the parched earth."
    },
    {
        "word": "Eigengrau",
        "pronunciation": "EYE-gen-grao",
        "partOfSpeech": "noun",
        "definition": "The dark grey colour seen by the eye in perfect darkness, as a result of signals from the optic nerves.",
        "etymology": "From German 'eigen' (own, intrinsic) and 'grau' (grey). Also called 'brain grey' or 'dark light'.",
        "synonyms": ["brain grey", "dark light", "intrinsic grey"],
        "exampleSentence": "Even in the pitch-black cave, her eyes perceived the eigengrau rather than true blackness."
    },
    {
        "word": "Kalopsia",
        "pronunciation": "kah-LOP-see-ah",
        "partOfSpeech": "noun",
        "definition": "A condition in which things appear more beautiful than they really are.",
        "etymology": "From Greek 'kalos' (beautiful) and 'opsis' (sight, view).",
        "synonyms": ["rosy perception", "beautifying vision"],
        "exampleSentence": "The golden hour cast a kalopsia over the tired old town, making even the crumbling walls look enchanting."
    },
    {
        "word": "Alexithymia",
        "pronunciation": "ah-lex-ih-THY-mee-ah",
        "partOfSpeech": "noun",
        "definition": "The inability to identify and describe emotions in oneself.",
        "etymology": "Coined in 1973 from Greek 'a' (without), 'lexis' (word), and 'thymos' (emotion, spirit).",
        "synonyms": ["emotional blindness", "feeling numbness"],
        "exampleSentence": "His alexithymia made it difficult for him to explain why the film had moved him to tears."
    },
    {
        "word": "Orphic",
        "pronunciation": "OR-fik",
        "partOfSpeech": "adjective",
        "definition": "Mysterious and entrancing; beyond ordinary understanding; mystical or oracular.",
        "etymology": "From Orpheus, the legendary Greek musician and poet who could charm all living things with his music.",
        "synonyms": ["mystical", "entrancing", "enigmatic"],
        "exampleSentence": "The orphic quality of the music seemed to transport the audience to another realm entirely."
    },
    {
        "word": "Meraki",
        "pronunciation": "meh-RAH-kee",
        "partOfSpeech": "noun",
        "definition": "The soul, creativity, or love put into something; the essence of yourself that you put into your work.",
        "etymology": "A modern Greek word derived from Turkish 'merak' (labour of love, to do something with pleasure).",
        "synonyms": ["creative passion", "soulful craft", "devotion"],
        "exampleSentence": "Every brushstroke revealed the artist's meraki — a deep personal investment in the canvas."
    },
    {
        "word": "Numinous",
        "pronunciation": "NOO-min-us",
        "partOfSpeech": "adjective",
        "definition": "Having a strong religious or spiritual quality; indicating or suggesting the presence of a divinity.",
        "etymology": "From Latin 'numen' (divine will, divine power), popularised by Rudolf Otto in his 1917 work 'Das Heilige'.",
        "synonyms": ["sacred", "transcendent", "divine"],
        "exampleSentence": "There was something numinous about the ancient cathedral that made even non-believers fall silent."
    },
    {
        "word": "Palimpsest",
        "pronunciation": "PAL-imp-sest",
        "partOfSpeech": "noun",
        "definition": "A manuscript or piece of writing material on which the original writing has been effaced to make room for later writing, but of which traces remain.",
        "etymology": "From Greek 'palimpsestos' (scraped again), from 'palin' (again) and 'psao' (to scrape).",
        "synonyms": ["overwritten text", "layered manuscript"],
        "exampleSentence": "The city itself was a palimpsest — Roman walls beneath medieval streets beneath modern tarmac."
    },
    {
        "word": "Crepuscular",
        "pronunciation": "kreh-PUS-kyoo-lar",
        "partOfSpeech": "adjective",
        "definition": "Of, resembling, or relating to twilight.",
        "etymology": "From Latin 'crepusculum' (twilight, dusk), diminutive of 'creper' (dark, dusky).",
        "synonyms": ["twilight", "dim", "dusky"],
        "exampleSentence": "The crepuscular light painted long shadows across the meadow as deer emerged to graze."
    },
    {
        "word": "Fernweh",
        "pronunciation": "FERN-vay",
        "partOfSpeech": "noun",
        "definition": "An ache for distant places; a craving for travel; the opposite of homesickness.",
        "etymology": "From German 'fern' (far, distant) and 'weh' (pain, ache). The opposite of 'Heimweh' (homesickness).",
        "synonyms": ["wanderlust", "travel yearning", "restlessness"],
        "exampleSentence": "Scrolling through photographs of mountain passes filled her with an unbearable fernweh."
    },
    {
        "word": "Komorebi",
        "pronunciation": "koh-moh-REH-bee",
        "partOfSpeech": "noun",
        "definition": "Sunlight filtering through the leaves of trees.",
        "etymology": "A Japanese word combining 'komor(u)' (to filter through) and 'bi' (sunlight). It has no direct English equivalent.",
        "synonyms": ["dappled sunlight", "leaf-light"],
        "exampleSentence": "They lay on the grass, watching the komorebi dance across the forest floor."
    },
    {
        "word": "Sillage",
        "pronunciation": "see-YAZH",
        "partOfSpeech": "noun",
        "definition": "The trail of scent left in the air or on surfaces by the wearer of a perfume.",
        "etymology": "From French 'sillage' (wake, trail), originally referring to the wake of a ship. From 'sillon' (furrow).",
        "synonyms": ["scent trail", "fragrance wake", "perfume trace"],
        "exampleSentence": "Her sillage lingered in the corridor long after she had left the room."
    },
    {
        "word": "Eleutheromania",
        "pronunciation": "el-oo-theh-roh-MAY-nee-ah",
        "partOfSpeech": "noun",
        "definition": "An intense and irresistible desire for freedom.",
        "etymology": "From Greek 'eleutheros' (free) and 'mania' (madness, obsession).",
        "synonyms": ["freedom obsession", "liberty craving"],
        "exampleSentence": "His eleutheromania drove him to quit his corporate job and sail around the world."
    },
    {
        "word": "Mamihlapinatapai",
        "pronunciation": "mah-mee-lah-pin-yah-tah-PIE",
        "partOfSpeech": "noun",
        "definition": "A look shared by two people, each wishing that the other would initiate something that they both desire but which neither wants to begin.",
        "etymology": "From the Yaghan language of Tierra del Fuego. Often cited as one of the hardest words to translate.",
        "synonyms": ["mutual hesitation", "shared longing"],
        "exampleSentence": "There was a moment of mamihlapinatapai across the table before he finally asked her to dance."
    },
    {
        "word": "Tsundoku",
        "pronunciation": "TSOON-doh-koo",
        "partOfSpeech": "noun",
        "definition": "The act of acquiring books and letting them pile up without reading them.",
        "etymology": "A Japanese portmanteau of 'tsunde' (to pile up) and 'oku' (to leave for a while). First used in the Meiji era (1868–1912).",
        "synonyms": ["book hoarding", "shelf stuffing"],
        "exampleSentence": "Her tsundoku had reached alarming proportions — every surface in the flat was covered with unread novels."
    },
    {
        "word": "Aeipathy",
        "pronunciation": "eye-IP-ah-thee",
        "partOfSpeech": "noun",
        "definition": "An enduring and consuming passion.",
        "etymology": "From Greek 'aei' (always, ever) and 'pathos' (feeling, suffering).",
        "synonyms": ["perpetual passion", "enduring devotion"],
        "exampleSentence": "Her aeipathy for marine biology led her from rockpools as a child to deep-sea research vessels."
    },
    {
        "word": "Querencia",
        "pronunciation": "keh-REN-see-ah",
        "partOfSpeech": "noun",
        "definition": "A place from which one's strength is drawn, where one feels at home; the place where you are your most authentic self.",
        "etymology": "From Spanish 'querer' (to desire, to love). In bullfighting, it refers to the spot in the ring where the bull feels safest.",
        "synonyms": ["sanctuary", "safe haven", "spiritual home"],
        "exampleSentence": "The old library became her querencia — the one place where the noise of the world fell away."
    },
    {
        "word": "Hiraeth",
        "pronunciation": "HEER-eyeth",
        "partOfSpeech": "noun",
        "definition": "A deep longing for a home you cannot return to, or that never was; a homesickness tinged with grief and sadness.",
        "etymology": "A Welsh word with no direct English translation. It combines elements of longing, nostalgia, and an earnest desire for home.",
        "synonyms": ["homesickness", "nostalgic longing", "yearning"],
        "exampleSentence": "Living abroad for decades, he was frequently visited by hiraeth — a longing for the Wales of his childhood."
    },
    {
        "word": "Ephemeral",
        "pronunciation": "eh-FEM-er-al",
        "partOfSpeech": "adjective",
        "definition": "Lasting for a very short time.",
        "etymology": "From Greek 'ephemeros' (lasting only a day), from 'epi' (on) and 'hemera' (day).",
        "synonyms": ["fleeting", "transient", "momentary"],
        "exampleSentence": "The cherry blossom season is all the more precious for being so ephemeral."
    },
    {
        "word": "Halcyon",
        "pronunciation": "HAL-see-on",
        "partOfSpeech": "adjective",
        "definition": "Denoting a period of time in the past that was idyllically happy and peaceful.",
        "etymology": "From Greek 'halkyon' (kingfisher). Ancient Greeks believed kingfishers nested on the sea, calming the waves around the winter solstice.",
        "synonyms": ["golden", "idyllic", "blissful"],
        "exampleSentence": "He often spoke of those halcyon summers spent at his grandparents' cottage by the lake."
    },
    {
        "word": "Syzygy",
        "pronunciation": "SIZ-ih-jee",
        "partOfSpeech": "noun",
        "definition": "An alignment of three or more celestial bodies in the same gravitational system along a straight line.",
        "etymology": "From Greek 'suzugia' (yoked together), from 'sun' (together) and 'zugon' (yoke). Solar and lunar eclipses occur at syzygy.",
        "synonyms": ["celestial alignment", "conjunction"],
        "exampleSentence": "The rare syzygy of Jupiter, Saturn, and the Moon created a spectacular night sky."
    },
    {
        "word": "Lacuna",
        "pronunciation": "lah-KOO-nah",
        "partOfSpeech": "noun",
        "definition": "An unfilled space or gap; a missing portion in a manuscript, text, or body of knowledge.",
        "etymology": "From Latin 'lacuna' (hole, pit, gap), related to 'lacus' (lake, pond).",
        "synonyms": ["gap", "void", "hiatus"],
        "exampleSentence": "There is a frustrating lacuna in the historical record between the 5th and 8th centuries."
    },
    {
        "word": "Supine",
        "pronunciation": "soo-PINE",
        "partOfSpeech": "adjective",
        "definition": "Lying face upwards; also, failing to act or protest as a result of moral weakness or indolence.",
        "etymology": "From Latin 'supinus' (lying face upward, thrown backwards), possibly related to 'sub' (under).",
        "synonyms": ["recumbent", "passive", "inert"],
        "exampleSentence": "He lay supine on the grass, watching clouds drift across the endless sky."
    },
    {
        "word": "Denouement",
        "pronunciation": "day-NOO-moh",
        "partOfSpeech": "noun",
        "definition": "The final part of a play, film, or narrative in which the strands of the plot are drawn together and matters are explained or resolved.",
        "etymology": "From French 'dénouer' (to untie), from 'dé-' (un-) and 'nouer' (to tie), from Latin 'nodus' (knot).",
        "synonyms": ["conclusion", "resolution", "climax"],
        "exampleSentence": "The denouement of the mystery was so unexpected that several audience members gasped."
    },
    {
        "word": "Susurrus",
        "pronunciation": "soo-SUR-us",
        "partOfSpeech": "noun",
        "definition": "A whispering or rustling sound.",
        "etymology": "From Latin 'susurrus' (a murmur, whisper). The word itself sounds like what it describes (onomatopoeia).",
        "synonyms": ["murmur", "whisper", "rustle"],
        "exampleSentence": "A soft susurrus filled the meadow as the evening breeze moved through the tall grass."
    },
    {
        "word": "Trouvaille",
        "pronunciation": "troo-VY",
        "partOfSpeech": "noun",
        "definition": "A lucky find; a fortunate discovery, especially of something delightful.",
        "etymology": "From French 'trouver' (to find). Literally 'a find' or 'a thing found'.",
        "synonyms": ["lucky find", "windfall", "discovery"],
        "exampleSentence": "The little café hidden behind the cathedral was the trouvaille of their holiday."
    },
    {
        "word": "Scripturient",
        "pronunciation": "skrip-TYOOR-ee-ent",
        "partOfSpeech": "adjective",
        "definition": "Having a consuming passion to write.",
        "etymology": "From Latin 'scripturire' (to desire to write), from 'scribere' (to write).",
        "synonyms": ["compelled to write", "writing-obsessed"],
        "exampleSentence": "The scripturient teenager filled notebook after notebook with stories and poems."
    },
    {
        "word": "Ailurophile",
        "pronunciation": "eye-LOOR-oh-file",
        "partOfSpeech": "noun",
        "definition": "A person who loves cats.",
        "etymology": "From Greek 'ailouros' (cat) and 'philos' (loving). The Greek word for cat may derive from 'aiolos' (quick-moving).",
        "synonyms": ["cat lover", "cat enthusiast"],
        "exampleSentence": "As a lifelong ailurophile, she could never walk past a stray without stopping to say hello."
    },
    {
        "word": "Redolent",
        "pronunciation": "RED-oh-lent",
        "partOfSpeech": "adjective",
        "definition": "Strongly reminiscent or suggestive of something; also, fragrant or sweet-smelling.",
        "etymology": "From Latin 'redolere' (to emit a scent), from 're-' (intensive) and 'olere' (to smell).",
        "synonyms": ["evocative", "fragrant", "reminiscent"],
        "exampleSentence": "The old house was redolent of lavender and beeswax, just as she remembered."
    },
    {
        "word": "Quiddity",
        "pronunciation": "KWID-ih-tee",
        "partOfSpeech": "noun",
        "definition": "The inherent nature or essence of someone or something; the quality that makes a thing what it is.",
        "etymology": "From medieval Latin 'quidditas', from 'quid' (what). A term from scholastic philosophy.",
        "synonyms": ["essence", "nature", "quintessence"],
        "exampleSentence": "The painter somehow captured the quiddity of autumn — not just the colours but the feeling."
    },
    {
        "word": "Anamnesis",
        "pronunciation": "an-am-NEE-sis",
        "partOfSpeech": "noun",
        "definition": "Recollection, especially of a supposed previous existence; the remembering of things past.",
        "etymology": "From Greek 'anamnesis' (remembrance), from 'ana' (back) and 'mnesis' (memory). Used by Plato to describe knowledge as recollection.",
        "synonyms": ["recollection", "reminiscence", "remembrance"],
        "exampleSentence": "The scent of woodsmoke triggered a powerful anamnesis — suddenly he was eight years old again, sitting by his grandfather's fire."
    },
    {
        "word": "Scintilla",
        "pronunciation": "sin-TIL-ah",
        "partOfSpeech": "noun",
        "definition": "A tiny trace or spark of a specified quality or feeling.",
        "etymology": "From Latin 'scintilla' (spark). Related to 'scintillate' (to sparkle or twinkle).",
        "synonyms": ["spark", "trace", "glimmer"],
        "exampleSentence": "There was not a scintilla of evidence to support the extraordinary claim."
    },
    {
        "word": "Recondite",
        "pronunciation": "REK-on-dite",
        "partOfSpeech": "adjective",
        "definition": "Little known; abstruse; dealing with something few people know about.",
        "etymology": "From Latin 'reconditus' (hidden, concealed), past participle of 'recondere' (to put away, hide).",
        "synonyms": ["obscure", "arcane", "esoteric"],
        "exampleSentence": "His lectures on recondite aspects of Byzantine law attracted only the most dedicated scholars."
    },
    {
        "word": "Petrichor",
        "pronunciation": "PET-ri-kor",
        "partOfSpeech": "noun",
        "definition": "The pleasant, earthy smell produced when rain falls on dry soil.",
        "etymology": "Coined in 1964 from Greek 'petra' (stone) and 'ichor' (the fluid that flows in the veins of the gods in Greek mythology).",
        "synonyms": ["earth scent", "rain smell"],
        "exampleSentence": "After weeks of drought, the first drops of rain released a glorious petrichor across the garden."
    },
    {
        "word": "Sonder",
        "pronunciation": "SON-der",
        "partOfSpeech": "noun",
        "definition": "The realisation that each random passer-by is living a life as vivid and complex as your own.",
        "etymology": "Coined by John Koenig in 'The Dictionary of Obscure Sorrows' (2012), from German 'sonder' (special) and French 'sonder' (to probe).",
        "synonyms": ["empathic awareness", "existential reflection"],
        "exampleSentence": "Standing in the busy station, she was struck by a wave of sonder as she watched hundreds of strangers rush past."
    },
    {
        "word": "Defenestration",
        "pronunciation": "dee-fen-eh-STRAY-shun",
        "partOfSpeech": "noun",
        "definition": "The act of throwing someone or something out of a window.",
        "etymology": "From Latin 'de' (down from) and 'fenestra' (window). Popularised after the Defenestrations of Prague in 1419 and 1618.",
        "synonyms": ["ejection", "expulsion"],
        "exampleSentence": "The defenestration of the laptop was perhaps an overreaction to the software update."
    },
    {
        "word": "Limerence",
        "pronunciation": "LIM-er-ence",
        "partOfSpeech": "noun",
        "definition": "The state of being infatuated or obsessed with another person, typically experienced involuntarily.",
        "etymology": "Coined by psychologist Dorothy Tennov in her 1979 book 'Love and Limerence'. The word has no known linguistic root.",
        "synonyms": ["infatuation", "obsessive love", "lovesickness"],
        "exampleSentence": "His limerence made it impossible to concentrate on anything except the hope of seeing her again."
    },
    {
        "word": "Sesquipedalian",
        "pronunciation": "ses-kwi-peh-DAY-lee-an",
        "partOfSpeech": "adjective",
        "definition": "Relating to or given to the use of long words.",
        "etymology": "From Latin 'sesquipedalis' (a foot and a half long), from 'sesqui' (one and a half) and 'pes' (foot). Horace used it in Ars Poetica.",
        "synonyms": ["grandiloquent", "verbose", "polysyllabic"],
        "exampleSentence": "His sesquipedalian prose style made even simple ideas sound impossibly complex."
    },
    {
        "word": "Ineffable",
        "pronunciation": "in-EFF-ah-bul",
        "partOfSpeech": "adjective",
        "definition": "Too great or extreme to be expressed or described in words.",
        "etymology": "From Latin 'ineffabilis', from 'in-' (not) and 'effabilis' (utterable), from 'effari' (to speak out).",
        "synonyms": ["inexpressible", "indescribable", "unspeakable"],
        "exampleSentence": "The view from the summit was ineffable — no photograph or description could do it justice."
    },
    {
        "word": "Chrysalism",
        "pronunciation": "KRIS-ah-liz-um",
        "partOfSpeech": "noun",
        "definition": "The amniotic tranquillity of being indoors during a thunderstorm, listening to rain and wind outside.",
        "etymology": "Coined by John Koenig in 'The Dictionary of Obscure Sorrows', from 'chrysalis' (the protective cocoon of a butterfly pupa).",
        "synonyms": ["storm comfort", "indoor peace"],
        "exampleSentence": "She wrapped herself in a blanket and surrendered to chrysalism as lightning cracked outside the window."
    },
    {
        "word": "Adamantine",
        "pronunciation": "ad-ah-MAN-teen",
        "partOfSpeech": "adjective",
        "definition": "Unbreakable; utterly unyielding; of or relating to the hardest substance.",
        "etymology": "From Greek 'adamantinos', from 'adamas' (unconquerable, invincible), which also gives us 'diamond' and 'adamant'.",
        "synonyms": ["unbreakable", "unyielding", "indestructible"],
        "exampleSentence": "Her adamantine resolve saw her through years of setbacks and disappointments."
    },
    {
        "word": "Obsequious",
        "pronunciation": "ob-SEE-kwee-us",
        "partOfSpeech": "adjective",
        "definition": "Obedient or attentive to an excessive or servile degree.",
        "etymology": "From Latin 'obsequiosus' (compliant, obedient), from 'obsequi' (to follow, comply with).",
        "synonyms": ["sycophantic", "fawning", "servile"],
        "exampleSentence": "The obsequious waiter hovered so closely that they could barely have a private conversation."
    },
    {
        "word": "Mellifluous",
        "pronunciation": "meh-LIF-loo-us",
        "partOfSpeech": "adjective",
        "definition": "Sweet-sounding; pleasant to hear, especially of a voice or words.",
        "etymology": "From Latin 'mellifluus', from 'mel' (honey) and 'fluere' (to flow). Literally 'flowing with honey'.",
        "synonyms": ["dulcet", "honeyed", "melodious"],
        "exampleSentence": "The narrator's mellifluous voice made even the driest passages of the audiobook enjoyable."
    },
    {
        "word": "Penumbra",
        "pronunciation": "peh-NUM-brah",
        "partOfSpeech": "noun",
        "definition": "The partially shaded outer region of a shadow cast by an opaque object; an area of partial illumination.",
        "etymology": "From Latin 'paene' (almost) and 'umbra' (shadow). Coined by astronomer Johannes Kepler in 1604.",
        "synonyms": ["half-shadow", "partial shade", "fringe"],
        "exampleSentence": "The Moon passed through Earth's penumbra, dimming slightly but not disappearing entirely."
    },
    {
        "word": "Serendipity",
        "pronunciation": "ser-en-DIP-ih-tee",
        "partOfSpeech": "noun",
        "definition": "The occurrence of events by chance in a happy or beneficial way.",
        "etymology": "Coined by Horace Walpole in 1754, inspired by the Persian fairy tale 'The Three Princes of Serendip', whose heroes were always making discoveries by accident.",
        "synonyms": ["happy accident", "fortunate chance", "providence"],
        "exampleSentence": "It was pure serendipity that she sat next to her future business partner on that delayed train."
    },
    {
        "word": "Nacreous",
        "pronunciation": "NAY-kree-us",
        "partOfSpeech": "adjective",
        "definition": "Resembling nacre (mother-of-pearl); having an iridescent, pearly lustre.",
        "etymology": "From French 'nacre' (mother-of-pearl), possibly from Arabic 'naqqarah' (small drum), referring to the shell shape.",
        "synonyms": ["pearly", "iridescent", "opalescent"],
        "exampleSentence": "The nacreous clouds at high altitude glowed with pastel colours in the polar twilight."
    },
    {
        "word": "Omphalos",
        "pronunciation": "OM-fah-loss",
        "partOfSpeech": "noun",
        "definition": "The centre or hub of something; literally, a navel. In ancient Greece, a sacred stone believed to mark the centre of the world.",
        "etymology": "From Greek 'omphalos' (navel). The most famous omphalos stone was at the Oracle of Delphi.",
        "synonyms": ["centre", "hub", "focal point"],
        "exampleSentence": "For decades, the old café served as the omphalos of the town's intellectual life."
    },
    {
        "word": "Sonorous",
        "pronunciation": "SON-or-us",
        "partOfSpeech": "adjective",
        "definition": "Having a deep, rich, resonant sound; imposingly grand in style.",
        "etymology": "From Latin 'sonorus' (resounding), from 'sonor' (sound). Related to 'sonic' and 'sonata'.",
        "synonyms": ["resonant", "booming", "full-toned"],
        "exampleSentence": "The sonorous toll of the cathedral bell echoed across the valley each evening."
    },
    {
        "word": "Imbroglio",
        "pronunciation": "im-BROAL-yoh",
        "partOfSpeech": "noun",
        "definition": "An extremely confused, complicated, or embarrassing situation.",
        "etymology": "From Italian 'imbroglio' (a tangle, confusion), from 'imbrogliare' (to confuse, entangle).",
        "synonyms": ["tangle", "predicament", "fiasco"],
        "exampleSentence": "The diplomatic imbroglio threatened to derail months of careful negotiation."
    },
    {
        "word": "Ethereal",
        "pronunciation": "ih-THEER-ee-al",
        "partOfSpeech": "adjective",
        "definition": "Extremely delicate and light in a way that seems too perfect for this world; heavenly or celestial.",
        "etymology": "From Latin 'aethereus', from Greek 'aitherios' (of the upper air), from 'aither' (the pure upper air breathed by the gods).",
        "synonyms": ["celestial", "otherworldly", "sublime"],
        "exampleSentence": "The dancer's movements were so ethereal that she seemed to float rather than step."
    },
    {
        "word": "Ubiquitous",
        "pronunciation": "yoo-BIK-wih-tus",
        "partOfSpeech": "adjective",
        "definition": "Present, appearing, or found everywhere.",
        "etymology": "From Latin 'ubique' (everywhere), from 'ubi' (where) and the generalising suffix '-que'.",
        "synonyms": ["omnipresent", "pervasive", "universal"],
        "exampleSentence": "Smartphones have become so ubiquitous that it feels strange to see someone without one."
    },
    {
        "word": "Languor",
        "pronunciation": "LANG-gor",
        "partOfSpeech": "noun",
        "definition": "The state or feeling of tiredness, inactivity, or pleasant laziness; a dreamy quality.",
        "etymology": "From Latin 'languor' (faintness, weariness), from 'languere' (to be faint or weak).",
        "synonyms": ["lethargy", "listlessness", "torpor"],
        "exampleSentence": "A delicious languor settled over the afternoon as the heat shimmered above the terrace."
    },
    {
        "word": "Reverie",
        "pronunciation": "REV-er-ee",
        "partOfSpeech": "noun",
        "definition": "A state of being pleasantly lost in one's thoughts; a daydream.",
        "etymology": "From French 'rêverie' (daydream), from 'rêver' (to dream). Earlier meanings included 'wild delight' or 'revelry'.",
        "synonyms": ["daydream", "musing", "wool-gathering"],
        "exampleSentence": "She was deep in reverie, gazing out the window, when the bell startled her back to reality."
    },
]


def get_words(count: int, seed: int) -> list[dict]:
    """Select `count` words from the bank using the given seed for reproducibility."""
    rng = random.Random(seed)
    # Shuffle a copy so we pick without bias
    pool = list(WORD_BANK)
    rng.shuffle(pool)
    # Cycle if count exceeds pool size (shouldn't happen with a large bank)
    selected = []
    while len(selected) < count:
        remaining = count - len(selected)
        selected.extend(pool[:remaining])
        rng.shuffle(pool)
    return selected


# ── Supabase Upload ────────────────────────────────────────────────────────

def upload_to_supabase(payload: dict):
    """Upload a word of the day to Supabase."""
    try:
        from supabase import create_client
    except ImportError:
        print("Install supabase: pip install supabase-py")
        sys.exit(1)

    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_KEY")
    if not url or not key:
        print("Set SUPABASE_URL and SUPABASE_KEY environment variables")
        sys.exit(1)

    client = create_client(url, key)
    result = client.table("words_of_the_day").insert(payload).execute()
    print(f"  Uploaded WOTD for {payload['date']}: {payload['word_data']['word']}")
    return result


# ── CLI ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Generate Words of the Day")
    parser.add_argument(
        "--count", type=int, default=7, help="Number of words to generate (default: 7)"
    )
    parser.add_argument("--date", type=str, help="Start date (YYYY-MM-DD)")
    parser.add_argument(
        "--dry-run", action="store_true", help="Generate without uploading"
    )
    parser.add_argument(
        "--output", type=str, help="Save JSON files to this directory"
    )
    args = parser.parse_args()

    start_date = date.fromisoformat(args.date) if args.date else date.today() + timedelta(days=1)

    # Use the start date as seed for reproducibility
    seed = int(start_date.isoformat().replace("-", ""))

    words = get_words(args.count, seed)

    print(f"Generating {args.count} WOTDs starting from {start_date.isoformat()}")

    for i, word_data in enumerate(words):
        word_date = start_date + timedelta(days=i)
        payload = {
            "date": word_date.isoformat(),
            "word_data": word_data,
        }

        print(f"  [{i + 1}/{args.count}] {word_data['word']} for {word_date.isoformat()}")

        if args.output:
            from pathlib import Path
            out_dir = Path(args.output)
            out_dir.mkdir(parents=True, exist_ok=True)
            out_file = out_dir / f"wotd_{word_date.isoformat()}.json"
            with open(out_file, "w") as f:
                json.dump(payload, f, indent=2)
            print(f"    Saved to {out_file}")

        if not args.dry_run:
            upload_to_supabase(payload)

    print("Done!")


if __name__ == "__main__":
    main()
