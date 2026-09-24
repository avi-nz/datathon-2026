import os
import requests
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("OPENROUTER_API_KEY")

if not API_KEY:
    raise ValueError("OPENROUTER_API_KEY is not set")

URL = "https://openrouter.ai/api/alpha/decisions"


def classify_referral(gp_note):

    data = {
        "model": "typesafe/jev-1.13",

        "state": gp_note,

        "questions": {
            "urgency": {
                "type": "choice",

                "instructions": """
                Based on the GP referral note, which treatment
                urgency category best describes this referral?
                """,

                "criteria": {
                    "urgent": """
                    The GP note contains a clear indication that
                    the patient needs priority clinical assessment
                    or treatment.
                    """,

                    "semi-urgent": """
                    The GP note indicates that the patient needs
                    clinical assessment within a shorter timeframe
                    than a routine referral, but does not indicate
                    an immediate or emergency need.
                    """,

                    "routine": """
                    The GP note describes a stable or non-worsening
                    condition where routine assessment or treatment
                    is appropriate.
                    """
                }
            }
        }
    }

    response = requests.post(
        URL,
        headers={
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json"
        },
        json=data
    )

    response.raise_for_status()

    result = response.json()

    return result["answers"]["urgency"]


