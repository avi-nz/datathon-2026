import boto3
import json
import os
from dotenv import load_dotenv

load_dotenv()

AWS_REGION = os.getenv("AWS_REGION", "ap-southeast-2")

client = boto3.client(
    "bedrock-runtime",
    region_name=AWS_REGION
)

MODEL_ID = "au.anthropic.claude-haiku-4-5-20251001-v1:0"


def generate_explanation(gp_note, classification):
    system_prompt = """
                    You are an AI assistant supporting a healthcare referral
                    coordination system.
                
                    Your role is to explain an existing referral classification
                    and provide a standard administrative workflow recommendation.
                
                    IMPORTANT RULES:
                
                    1. Jev has already classified the referral.
                    2. You MUST NOT change the Jev classification.
                    3. Do not provide a medical diagnosis.
                    4. Do not provide medical treatment advice.
                    5. Base the justification only on information contained in
                       the GP referral note.
                    6. Do not invent symptoms, patient information, or clinical
                       information.
                    7. Provide exactly THREE reasons explaining why the referral
                       meets the Jev classification.
                    8. Each reason must be based on information in the referral.
                    9. Provide ONE workflow recommendation.
                    10. The recommendation must be specific to the referral.
                    11. Identify the relevant service, department, specialist,
                        or appointment type from the GP referral note when this
                        information is available.
                    12. Use the Jev classification to determine the urgency of
                        the workflow.
                    13. The recommendation must remain administrative.
                    14. Do not provide medical diagnosis or treatment advice.
                    15. Return JSON only.
                    16. Do not use Markdown or code fences.
                
                    WORKFLOW RULES:
                
                    URGENT:
                    Use the priority referral pathway.
                    Schedule the relevant next appointment as a priority.
                    Use the service or specialist identified in the referral.
                
                    SEMI-URGENT:
                    Use the prioritised referral pathway.
                    Schedule the relevant next appointment within the
                    appropriate timeframe.
                    Use the service or specialist identified in the referral.
                
                    ROUTINE:
                    Use the standard referral pathway.
                    Schedule the relevant next appointment within normal
                    waiting list parameters.
                    No priority acceleration or expedited review is required.
                
                    The recommendation must be specific to the patient's
                    referral.
                
                    For example, if the referral is for physiotherapy,
                    recommend a physiotherapy assessment.
                
                    If the referral is for cardiology, recommend a cardiology
                    appointment.
                
                    If the referral identifies a hospital outpatient clinic,
                    recommend an appointment with that clinic.
                
                    Do not replace the identified service with a generic phrase
                    such as "relevant hospital, specialist, or clinical service"
                    when the referral provides more specific information.
                
                    Required JSON:
                
                    {
                        "justification": {
                            "reason_1": "...",
                            "reason_2": "...",
                            "reason_3": "..."
                        },
                        "recommendation": "..."
                    }
                    """

    user_prompt = f"""
                    GP referral note:
                    
                    {gp_note}
                    
                    Jev classification:
                    
                    {classification}
                    
                    Generate the required JSON response.
                    """

    response = client.converse(
        modelId=MODEL_ID,
        system=[
            {
                "text": system_prompt
            }
        ],
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "text": user_prompt
                    }
                ]
            }
        ]
    )

    text = response["output"]["message"]["content"][0]["text"]

    # Remove whitespace
    text = text.strip()

    # Remove Markdown code fences if Claude adds them
    if text.startswith("```json"):
        text = text[7:]

    elif text.startswith("```"):
        text = text[3:]

    if text.endswith("```"):
        text = text[:-3]

    text = text.strip()

    # Convert Claude's response into a Python dictionary
    result = json.loads(text)

    # Make sure the classification cannot be changed by Claude
    result["classification"] = classification

    return result