"""KLF card generator — reads eval JSON, enforces the claims law.

The card text is DERIVED from measured results; SOTA-in-class vs
class-exclusive distinction is decided by the data structure, not by
whoever writes the card.
"""
import argparse
import json


def claim_kind(entry):
    eval_ = entry.get("eval", {})
    if eval_.get("official"):
        return ("**Measured SOTA in its weight class**",
                "official benchmark score; no model we know of occupies "
                "the <=250MB fully-local CPU class at this level")
    return ("**Class-exclusive**",
            "the only fully-local <=250MB model we know of for this "
            "language; quality measured by the stated protocol")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("eval_json")
    ap.add_argument("out_md")
    a = ap.parse_args()
    e = json.load(open(a.eval_json))
    title, claim = claim_kind(e)
    eval_ = e["eval"]
    if eval_.get("official"):
        eval_md = (f"| Precision | Recall | F0.5 |\n|---|---|---|\n"
                   f"| {eval_['P']} | {eval_['R']} | **{eval_['F0.5']}** |")
    else:
        j = eval_.get("judge_500", {})
        eval_md = (f"| Measure | Result |\n|---|---|\n"
                   f"| Left unchanged | {eval_.get('unchanged', '-')} |\n"
                   f"| Judge: improved / harmed | {j.get('improved','-')} / {j.get('harmed','-')} |")
    card = f"""# {e['id']} v{e['version']}

Fully local {e['language']} grammar correction for the **weight class**
(run anywhere, CPU real-time, no network).

{title} — {claim}.

{eval_md}

License: {e['license']}. {e['eval'].get('note', '')}
"""
    open(a.out_md, "w").write(card)
    print(f"card -> {a.out_md}")


if __name__ == "__main__":
    main()
