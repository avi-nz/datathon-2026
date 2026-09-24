import json

from jev import classify_referral
from bedrock import generate_explanation


def main():

    # Read referral note from text file
    with open("urgent_referral.txt", "r", encoding="utf-8") as file:
        gp_note = file.read()

    if not gp_note.strip():
        print("Error: referral file is empty.")
        return

    # Classify the referral with Jev
    jev_result = classify_referral(gp_note)

    classification = jev_result["choice"]
    confidence = jev_result.get("confidence")
    probabilities = jev_result.get("probabilities", {})

    # Generate explanation and recommendation
    bedrock_result = generate_explanation(
        gp_note,
        classification
    )

    # Combine the results
    final_result = {
        "classification": classification,
        "confidence": confidence,
        "probabilities": probabilities,
        "justification": bedrock_result["justification"],
        "recommendation": bedrock_result["recommendation"]
    }

    # Print final JSON
    print("\nFinal result:")
    print(json.dumps(final_result, indent=2))


if __name__ == "__main__":
    main()