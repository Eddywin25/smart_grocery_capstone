"""Log produce photos the recognition model got wrong, so the model can be retrained later.

When a user corrects a scan (e.g. the model said Lemon but it's a Lime), the app sends the
photo and both labels here. The photo is saved to Cloud Storage at
misidentified/{uid}/{reportId}.jpg and the details to the 'misidentifications' collection.
Grouping the photos by correctLabel gives labeled training data.

The app should ask the user before sending their photo.
"""

import base64
import binascii
from datetime import UTC, datetime

from google.cloud.firestore import FieldFilter
from user_data import bad_request, is_text

MAX_IMAGE_BYTES = 5 * 1024 * 1024  # 5 MB; the app should send a compressed photo
SOURCES = ["edgeMl", "geminiCloud"]

# The first bytes of each allowed image type, so other files can't be uploaded as "photos"
IMAGE_TYPES = {
    b"\xff\xd8\xff": ("jpg", "image/jpeg"),
    b"\x89PNG\r\n\x1a\n": ("png", "image/png"),
}


def decode_image(image) -> tuple[bytes, str, str]:
    """Return (bytes, extension, content type) for a base64 photo, or stop if it's invalid."""
    if not is_text(image):
        raise bad_request("image must be a base64-encoded JPEG or PNG")

    # Accept a data URL too, e.g. "data:image/jpeg;base64,/9j/4AAQ..."
    if image.startswith("data:") and "," in image:
        image = image.split(",", 1)[1]

    try:
        data = base64.b64decode(image, validate=True)
    except (binascii.Error, ValueError) as error:
        raise bad_request("image must be valid base64") from error

    if len(data) > MAX_IMAGE_BYTES:
        raise bad_request(f"image must be {MAX_IMAGE_BYTES // (1024 * 1024)} MB or smaller")

    for signature, (extension, content_type) in IMAGE_TYPES.items():
        if data.startswith(signature):
            return data, extension, content_type
    raise bad_request("image must be a JPEG or PNG")


def validated_report(data: dict) -> dict:
    """Return the report details to save, or stop with everything that's wrong."""
    predicted = data.get("predictedLabel")
    correct = data.get("correctLabel")
    confidence = data.get("confidence")
    source = data.get("source")
    alternatives = data.get("alternatives", [])
    model_version = data.get("modelVersion")

    problems = []
    if not is_text(predicted):
        problems.append("predictedLabel must be non-empty text")
    if not is_text(correct):
        problems.append("correctLabel must be non-empty text")
    if (
        is_text(predicted)
        and is_text(correct)
        and predicted.strip().lower() == correct.strip().lower()
    ):
        problems.append("correctLabel is the same as predictedLabel, so nothing was misidentified")
    # (True/False count as numbers in Python, so they are rejected separately)
    is_number = isinstance(confidence, (int, float)) and not isinstance(confidence, bool)
    if not is_number or not 0 <= confidence <= 1:
        problems.append("confidence must be a number from 0 to 1")
    if source not in SOURCES:
        problems.append(f"source must be one of {SOURCES}")
    if not isinstance(alternatives, list) or not all(is_text(a) for a in alternatives):
        problems.append("alternatives must be a list of text")
    if model_version is not None and not is_text(model_version):
        problems.append("modelVersion must be non-empty text")
    if problems:
        raise bad_request("; ".join(problems))

    report = {
        "predictedLabel": predicted.strip(),
        "correctLabel": correct.strip(),
        "confidence": float(confidence),
        "source": source,
        "alternatives": [a.strip() for a in alternatives],
    }
    if model_version is not None:
        report["modelVersion"] = model_version.strip()
    return report


def report_misidentification(db, bucket, uid: str, data: dict) -> dict:
    """Save the photo and details of a scan the user corrected, and return the report id.

    Sends: image (base64 JPEG or PNG), predictedLabel, correctLabel, confidence (0-1),
    source (edgeMl | geminiCloud), and optionally alternatives and modelVersion.
    """
    # Check everything before saving anything
    report = validated_report(data)
    image, extension, content_type = decode_image(data.get("image"))

    doc = db.collection("misidentifications").document()  # Firestore picks a new ID
    image_path = f"misidentified/{uid}/{doc.id}.{extension}"
    bucket.blob(image_path).upload_from_string(image, content_type=content_type)

    doc.set(
        {
            **report,
            "uid": uid,
            "imagePath": image_path,
            "createdAt": datetime.now(UTC).isoformat(),
        }
    )
    return {"id": doc.id}


def delete_user_reports(db, bucket, uid: str) -> None:
    """Delete all of a user's misidentification photos and reports (used by delete_account)."""
    for blob in bucket.list_blobs(prefix=f"misidentified/{uid}/"):
        blob.delete()

    reports = db.collection("misidentifications").where(filter=FieldFilter("uid", "==", uid))
    for doc in reports.stream():
        doc.reference.delete()
