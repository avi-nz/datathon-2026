import json
from pipeline.jev import classify_referral
from pipeline.bedrock import generate_explanation
from common.db import fetch_unprocessed_referrals, store_result


def process_referral(referral_id, gp_note):
    jev_result = classify_referral(gp_note)
    classification = jev_result["choice"]
    confidence = jev_result.get("confidence")
    probabilities = jev_result.get("probabilities", {})

    bedrock_result = generate_explanation(gp_note, classification)

    return {
        "referral_id": referral_id,
        "classification": classification,
        "confidence": confidence,
        "probabilities": probabilities,
        "justification": bedrock_result["justification"],
        "recommendation": bedrock_result["recommendation"],
    }


def main():
    referrals = fetch_unprocessed_referrals()
    print(f"Found {len(referrals)} unprocessed referrals")

    for r in referrals:
        print(f"Processing {r['referral_id']}...")
        result = process_referral(r["referral_id"], r["reason_text"])
        store_result(result)
        print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main()
