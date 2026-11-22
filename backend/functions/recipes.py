"""Suggest recipes that use the groceries about to expire.

Spoonacular is searched first, since it takes several ingredients at once and ranks recipes by
how few extra ingredients they need. If it finds nothing, the item that expires last is
dropped and the search is tried again. If Spoonacular is down, out of daily requests, or has
no API key, TheMealDB (free, one ingredient at a time) is used instead.

No results is a normal answer, not an error: the app gets an empty list and a message.
Only when every search fails to connect does the app get an "unavailable" error.
"""

import re
from datetime import UTC, datetime, timedelta

import requests
from barcode_lookup import USER_AGENT
from expiry import food_key, parse_date
from firebase_functions.https_fn import FunctionsErrorCode, HttpsError
from user_data import bad_request, inventory, is_date

SPOONACULAR_URL = "https://api.spoonacular.com/recipes/findByIngredients"
# "1" is TheMealDB's public key for development and educational apps
THEMEALDB_URL = "https://www.themealdb.com/api/json/v1/1/filter.php"
TIMEOUT_SECONDS = 5

DEFAULT_WITHIN_DAYS = 3
MAX_WITHIN_DAYS = 14
MAX_INGREDIENTS = 4
RECIPES_PER_SEARCH = 5


class SearchFailed(Exception):
    """A recipe service couldn't be reached or sent an unusable answer."""


def expiring_ingredients(db, uid: str, within_days: int) -> list[str]:
    """Return simple names of the user's active items expiring soon, soonest first.

    Items that expired before today are left out, so we never suggest cooking spoiled food.
    Names are simplified for searching ("Fuji Apple" -> "apple") and repeats are removed.
    """
    now = datetime.now(UTC)
    start_of_today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    cutoff = now + timedelta(days=within_days)
    expiring = []

    for doc in inventory(db, uid).stream():
        item = doc.to_dict()
        if item.get("status", "active") != "active" or not is_date(item.get("expiryDate")):
            continue
        expiry_date = parse_date(item["expiryDate"])
        if start_of_today <= expiry_date <= cutoff:
            expiring.append((expiry_date, item.get("name", "")))

    names = []
    for _, name in sorted(expiring, key=lambda pair: pair[0]):
        simple = food_key(name) or name.strip().lower()
        if simple and simple not in names:
            names.append(simple)
    return names[:MAX_INGREDIENTS]


def get_json(url: str, params: dict, headers: dict | None = None):
    """Fetch JSON from a recipe service, or raise SearchFailed."""
    try:
        response = requests.get(
            url,
            params=params,
            headers={"User-Agent": USER_AGENT, **(headers or {})},
            timeout=TIMEOUT_SECONDS,
        )
        # Covers outages, and 402/429 when the daily request limit is used up
        response.raise_for_status()
        return response.json()
    except (requests.RequestException, ValueError) as error:
        raise SearchFailed(str(error)) from error


def search_spoonacular(ingredients: list[str], api_key: str) -> list[dict]:
    """Return Spoonacular recipes that use these ingredients, fewest missing ones first."""
    answer = get_json(
        SPOONACULAR_URL,
        params={
            "ingredients": ",".join(ingredients),
            "number": RECIPES_PER_SEARCH,
            "ranking": 2,  # minimize ingredients the user doesn't have
            "ignorePantry": "true",  # don't count water, salt, flour, etc. as missing
        },
        headers={"x-api-key": api_key},
    )
    if not isinstance(answer, list):
        raise SearchFailed("Spoonacular didn't send a list")

    recipes = []
    for recipe in answer:
        title = recipe.get("title")
        if not title or "id" not in recipe:
            continue
        slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
        recipes.append(
            {
                "title": title,
                "imageUrl": recipe.get("image") or "",
                "url": f"https://spoonacular.com/recipes/{slug}-{recipe['id']}",
                "usedIngredients": [i.get("name") for i in recipe.get("usedIngredients", [])],
                "missedIngredientCount": recipe.get("missedIngredientCount"),
                "source": "spoonacular",
            }
        )
    return recipes


def search_themealdb(ingredient: str) -> list[dict]:
    """Return TheMealDB recipes that use one ingredient."""
    answer = get_json(THEMEALDB_URL, params={"i": ingredient.replace(" ", "_")})
    if not isinstance(answer, dict):
        raise SearchFailed("TheMealDB didn't send an object")

    recipes = []
    for meal in (answer.get("meals") or [])[:RECIPES_PER_SEARCH]:
        if not meal.get("strMeal") or not meal.get("idMeal"):
            continue
        recipes.append(
            {
                "title": meal["strMeal"],
                "imageUrl": meal.get("strMealThumb") or "",
                "url": f"https://www.themealdb.com/meal/{meal['idMeal']}",
                "usedIngredients": [ingredient],
                "missedIngredientCount": None,  # TheMealDB doesn't say
                "source": "themealdb",
            }
        )
    return recipes


def find_recipes(db, uid: str, data: dict, api_key: str | None) -> dict:
    """Find recipes for the user's expiring groceries.

    Sends: optionally withinDays (1-14, default 3).
    Returns: ingredients (the ones searched), recipes, and a message when there are none.
    """
    within_days = data.get("withinDays", DEFAULT_WITHIN_DAYS)
    if (
        isinstance(within_days, bool)
        or not isinstance(within_days, int)
        or not 1 <= within_days <= MAX_WITHIN_DAYS
    ):
        raise bad_request(f"withinDays must be a whole number from 1 to {MAX_WITHIN_DAYS}")

    expiring = expiring_ingredients(db, uid, within_days)
    if not expiring:
        return {
            "ingredients": [],
            "recipes": [],
            "message": f"Nothing in your inventory expires in the next {within_days} days.",
        }

    any_search_worked = False

    # 1. Spoonacular with every expiring item, then drop the one expiring last, and repeat
    if api_key:
        for count in range(len(expiring), 0, -1):
            try:
                recipes = search_spoonacular(expiring[:count], api_key)
            except SearchFailed:
                break  # down or out of requests: no point retrying, go to TheMealDB
            any_search_worked = True
            if recipes:
                return {"ingredients": expiring[:count], "recipes": recipes}

    # 2. TheMealDB, one ingredient at a time, soonest-expiring first
    for ingredient in expiring:
        try:
            recipes = search_themealdb(ingredient)
        except SearchFailed:
            continue
        any_search_worked = True
        if recipes:
            return {"ingredients": [ingredient], "recipes": recipes}

    if not any_search_worked:
        raise HttpsError(
            FunctionsErrorCode.UNAVAILABLE,
            "Recipe search is unavailable right now. Please try again later.",
        )
    return {
        "ingredients": expiring,
        "recipes": [],
        "message": "No recipes found for your expiring items. Try again as you add more groceries.",
    }
