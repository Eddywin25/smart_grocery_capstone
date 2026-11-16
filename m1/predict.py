
"""
Smart Grocery Housekeeping
25-Class Grocery Recognition Inference Module

Loads a trained TensorFlow Lite model, preprocesses grocery
images, and returns predicted grocery categories.

Model input: 224 x 224 RGB images
Image normalization: [-1, 1]
Model output: 25 class scores
"""

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import tensorflow as tf
from PIL import Image, UnidentifiedImageError


# ---------------------------------------------------------
# Configuration
# ---------------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent

MODEL_PATH = BASE_DIR / "models" / "smart_grocery_model_25.tflite"
LABELS_PATH = BASE_DIR / "models" / "grocery_labels_25.json"

IMAGE_SIZE = (224, 224)
EXPECTED_CLASSES = 25
CONFIDENCE_WARNING = 0.60


# ---------------------------------------------------------
# Model and label loading
# ---------------------------------------------------------

def load_labels():
    """Load the model's class-index-to-name mapping"""

    if not LABELS_PATH.exists():
        raise FileNotFoundError(
            f"Label file not found: {LABELS_PATH}"
        )

    with open(LABELS_PATH, "r", encoding="utf-8") as file:
        raw_labels = json.load(file)

    labels = {
        int(index): name
        for index, name in raw_labels.items()
    }

    if len(labels) != EXPECTED_CLASSES:
        raise ValueError(
            f"Expected {EXPECTED_CLASSES} labels, "
            f"found {len(labels)}."
        )

    return labels


def load_model():
    """Initialize and prepare TensorFlow Lite interpreter"""

    if not MODEL_PATH.exists():
        raise FileNotFoundError(
            f"Model file not found: {MODEL_PATH}"
        )

    interpreter = tf.lite.Interpreter(
        model_path=str(MODEL_PATH)
    )

    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    return interpreter, input_details, output_details


# ---------------------------------------------------------
# Image preprocessing
# ---------------------------------------------------------

def preprocess_image(image_path):
    """
    Load image and prepare it for model inference.

    Converts image to RGB, resizes to 224x224,
    normalizes pixel values to [-1, 1], and adds batch
    dimension.
    """

    image_path = Path(image_path)

    if not image_path.exists():
        raise FileNotFoundError(
            f"Image not found: {image_path}"
        )

    try:
        with Image.open(image_path) as image:
            image = image.convert("RGB")
            image = image.resize(IMAGE_SIZE)

            image_array = np.asarray(
                image,
                dtype=np.float32
            )

    except UnidentifiedImageError as error:
        raise ValueError(
            "The supplied file is not a valid image"
        ) from error

    # Match the normalization used during model training.
    image_array = (image_array / 127.5) - 1.0

    # Shape becomes (1, 224, 224, 3).
    image_array = np.expand_dims(
        image_array,
        axis=0
    )

    return image_array


# ---------------------------------------------------------
# Prediction
# ---------------------------------------------------------

def predict(image_path, interpreter=None):
    """
    Predict the grocery category in an image.

    Returns the predicted class, confidence score,
    and the three highest-scoring predictions.
    """

    labels = load_labels()

    # Allow interpreter reuse for multiple predictions
    if interpreter is None:
        interpreter, input_details, output_details = (
            load_model()
        )
    else:
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()

    image = preprocess_image(image_path)

    expected_shape = tuple(
        input_details[0]["shape"]
    )

    if tuple(image.shape) != expected_shape:
        raise ValueError(
            f"Expected input shape {expected_shape}, "
            f"received {image.shape}."
        )

    interpreter.set_tensor(
        input_details[0]["index"],
        image
    )

    interpreter.invoke()

    scores = interpreter.get_tensor(
        output_details[0]["index"]
    )[0]

    if len(scores) != len(labels):
        raise ValueError(
            "Model output count does not match label count"
        )

    predicted_index = int(np.argmax(scores))

    top_indices = np.argsort(scores)[::-1][:3]

    top_predictions = []

    for index in top_indices:
        top_predictions.append({
            "item": labels[int(index)],
            "confidence": float(scores[index])
        })

    result = {
        "item": labels[predicted_index],
        "confidence": float(scores[predicted_index]),
        "top_predictions": top_predictions
    }

    return result


# ---------------------------------------------------------
# Result formatting
# ---------------------------------------------------------

def display_result(result):
    """Display prediction results in a readable format."""

    print("\nSMART GROCERY RECOGNITION")
    print("------------------------")

    print(
        f"Predicted grocery: {result['item']}"
    )

    confidence = result["confidence"]

    print(
        f"Confidence: {confidence:.2%}"
    )

    if confidence < CONFIDENCE_WARNING:
        print(
            "Warning: Low-confidence prediction. "
            "Consider manual confirmation or cloud fallback."
        )

    print("\nTOP THREE PREDICTIONS")

    for position, prediction in enumerate(
        result["top_predictions"],
        start=1
    ):
        print(
            f"{position}. {prediction['item']}: "
            f"{prediction['confidence']:.2%}"
        )


# ---------------------------------------------------------
# Command-line interface
# ---------------------------------------------------------

def main():
    """Handle command-line arguments and run inference"""

    parser = argparse.ArgumentParser(
        description=(
            "Identify groceries using the "
            "Smart Grocery 25-class model."
        )
    )

    parser.add_argument(
        "image",
        help="Path to the grocery image."
    )

    args = parser.parse_args()

    try:
        result = predict(args.image)
        display_result(result)

    except (
        FileNotFoundError,
        ValueError,
        OSError,
        RuntimeError
    ) as error:
        print(
            f"\nError: {error}",
            file=sys.stderr
        )

        sys.exit(1)


if __name__ == "__main__":
    main()
