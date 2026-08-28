import win32com.client
from datetime import datetime, timedelta
import os
import re
import hashlib


DAYS_BACK = 28
OUTPUT_FOLDER = r"C:\E-mail audit"

OL_FOLDER_INBOX = 6
OL_FOLDER_SENT_MAIL = 5
OL_MAIL_ITEM = 43


ME_PATTERNS = [
    r"\bkutryb\.m\b",
    r"\bmichal\b",
    r"\bmichał\b",
    r"\bmichael\b",
    r"\bkutryb\b",
    r"\bmichal\s+kutryb\b",
    r"\bmichał\s+kutryb\b",
    r"\bmichael\s+kutryb\b",
]


ACTION_PATTERNS = [
    r"\baction\b",
    r"\bactions\b",
    r"\baction item\b",
    r"\baction items\b",
    r"\bto do\b",
    r"\btodo\b",
    r"\bfollow up\b",
    r"\bfollow-up\b",
    r"\bplease\b",
    r"\bpls\b",
    r"\bcan you\b",
    r"\bcould you\b",
    r"\bwould you\b",
    r"\bneed you to\b",
    r"\byou need to\b",
    r"\bneed to\b",
    r"\bwe need to\b",
    r"\brequired\b",
    r"\brequirement\b",
    r"\bpending\b",
    r"\bowner\b",
    r"\bassigned\b",
    r"\bresponsible\b",
    r"\bdeadline\b",
    r"\bdue\b",
    r"\bby eod\b",
    r"\beod\b",
    r"\basap\b",
    r"\burgent\b",
    r"\breminder\b",
    r"\bnext step\b",
    r"\bnext steps\b",
    r"\bopen point\b",
    r"\bopen points\b",
    r"\bwaiting for\b",
    r"\bawaiting\b",
    r"\bconfirm\b",
    r"\bconfirmation\b",
    r"\breview\b",
    r"\bapprove\b",
    r"\bapproval\b",
    r"\bcheck\b",
    r"\bverify\b",
    r"\bsend\b",
    r"\bprovide\b",
    r"\bprepare\b",
    r"\bupdate\b",
    r"\bshare\b",
]


QUOTE_START_PATTERNS = [
    r"^from:\s",
    r"^sent:\s",
    r"^to:\s",
    r"^subject:\s",
    r"^-{2,}\s*original message\s*-{2,}",
    r"^on .+ wrote:",
    r"^od:\s",
    r"^wysłano:\s",
    r"^do:\s",
    r"^temat:\s",
]


def safe_get(value):
    try:
        if value is None:
            return ""
        return str(value)
    except Exception:
        return ""


def normalize_text(text):
    text = safe_get(text)
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"[ \t]+", " ", text)
    return text.strip()


def clean_for_matching(text):
    text = safe_get(text).lower()

    replacements = {
        "ą": "a",
        "ć": "c",
        "ę": "e",
        "ł": "l",
        "ń": "n",
        "ó": "o",
        "ś": "s",
        "ź": "z",
        "ż": "z",
    }

    for polish_char, latin_char in replacements.items():
        text = text.replace(polish_char, latin_char)

    return text


def strip_quoted_history(body):
    body = normalize_text(body)
    lines = body.split("\n")

    kept_lines = []

    for line in lines:
        line_clean = line.strip().lower()

        is_quote_start = False

        for pattern in QUOTE_START_PATTERNS:
            if re.search(pattern, line_clean, re.IGNORECASE):
                is_quote_start = True
                break

        if is_quote_start and len(kept_lines) > 3:
            break

        kept_lines.append(line)

    result = "\n".join(kept_lines).strip()

    return result[:6000]


def contains_me(text):
    cleaned = clean_for_matching(text)

    for pattern in ME_PATTERNS:
        pattern_cleaned = clean_for_matching(pattern)

        if re.search(pattern_cleaned, cleaned, re.IGNORECASE):
            return True

    return False


def contains_action(text):
    cleaned = clean_for_matching(text)

    for pattern in ACTION_PATTERNS:
        pattern_cleaned = clean_for_matching(pattern)

        if re.search(pattern_cleaned, cleaned, re.IGNORECASE):
            return True

    return False


def split_into_candidate_lines(text):
    text = normalize_text(text)

    rough_parts = []

    for line in text.split("\n"):
        line = line.strip()

        if not line:
            continue

        pieces = re.split(r"(?<=[.!?])\s+", line)
        rough_parts.extend(pieces)

    candidates = []

    for part in rough_parts:
        part = part.strip(" -•\t")
        part = normalize_text(part)

        if len(part) < 8:
            continue

        if len(part) > 500:
            part = part[:500] + "..."

        candidates.append(part)

    return candidates


def make_dedupe_key(text):
    cleaned = clean_for_matching(text)
    cleaned = re.sub(r"\s+", " ", cleaned)
    cleaned = re.sub(r"[^a-z0-9 .@_-]", "", cleaned)
    cleaned = cleaned.strip()

    return hashlib.sha256(cleaned.encode("utf-8", errors="ignore")).hexdigest()


def get_sender_email(item):
    try:
        return safe_get(item.SenderEmailAddress)
    except Exception:
        return ""


def get_sender_name(item):
    try:
        return safe_get(item.SenderName)
    except Exception:
        return ""


def get_item_date(item, source):
    try:
        if source == "Received":
            return item.ReceivedTime
        else:
            return item.SentOn
    except Exception:
        return None


def get_message_id(item):
    try:
        return safe_get(
            item.PropertyAccessor.GetProperty(
                "http://schemas.microsoft.com/mapi/proptag/0x1035001E"
            )
        )
    except Exception:
        return ""


def extract_actions_from_item(item, source):
    subject = safe_get(item.Subject)
    body = strip_quoted_history(safe_get(item.Body))

    full_search_text = subject + "\n" + body

    has_me = contains_me(full_search_text)
    has_action = contains_action(full_search_text)

    if not has_action:
        return []

    candidates = split_into_candidate_lines(body)

    found = []

    for line in candidates:
        line_has_me = contains_me(line)
        line_has_action = contains_action(line)

        if line_has_me and line_has_action:
            priority = "High"

        elif has_me and line_has_action:
            priority = "Medium"

        elif source == "Received" and line_has_action and has_me:
            priority = "Medium"

        else:
            continue

        found.append({
            "priority": priority,
            "action_text": line,
            "subject": subject,
            "date": get_item_date(item, source),
            "source": source,
            "from_name": get_sender_name(item),
            "from_email": get_sender_email(item),
            "to": safe_get(item.To),
            "cc": safe_get(item.CC),
            "message_id": get_message_id(item),
        })

    if not found and contains_action(subject):
        found.append({
            "priority": "Medium" if has_me else "Low",
            "action_text": "Subject indicates possible action: " + subject,
            "subject": subject,
            "date": get_item_date(item, source),
            "source": source,
            "from_name": get_sender_name(item),
            "from_email": get_sender_email(item),
            "to": safe_get(item.To),
            "cc": safe_get(item.CC),
            "message_id": get_message_id(item),
        })

    return found


def scan_folder(namespace, folder_id, source, cutoff):
    folder = namespace.GetDefaultFolder(folder_id)
    items = folder.Items

    sort_field = "[ReceivedTime]" if source == "Received" else "[SentOn]"
    items.Sort(sort_field, True)

    results = []

    print(f"Scanning {source} folder...")

    for item in items:
        try:
            if item.Class != OL_MAIL_ITEM:
                continue

            item_date = get_item_date(item, source)

            if item_date is None:
                continue

            item_date_no_tz = item_date.replace(tzinfo=None)

            if item_date_no_tz < cutoff:
                break

            actions = extract_actions_from_item(item, source)
            results.extend(actions)

        except Exception as e:
            print(f"Skipped one {source} item due to error: {e}")

    print(f"Found possible {source} action lines: {len(results)}")
    return results


def write_report(actions, output_file, cutoff):
    seen = set()
    deduped = []

    for action in actions:
        key_text = action["subject"] + " | " + action["action_text"]
        key = make_dedupe_key(key_text)

        if key in seen:
            continue

        seen.add(key)
        deduped.append(action)

    priority_order = {
        "High": 1,
        "Medium": 2,
        "Low": 3,
    }

    deduped.sort(
        key=lambda x: (
            priority_order.get(x["priority"], 9),
            x["date"] if x["date"] else datetime.min
        )
    )

    with open(output_file, "w", encoding="utf-8") as f:
        f.write("Outlook possible action items related to Michal / Michał / Michael Kutryb\n")
        f.write(
            f"Period: {cutoff.strftime('%Y-%m-%d %H:%M:%S')} "
            f"to {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
        )
        f.write(f"Exported at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Total possible actions after deduplication: {len(deduped)}\n")
        f.write("=" * 120 + "\n\n")

        current_priority = None

        for idx, action in enumerate(deduped, start=1):
            if action["priority"] != current_priority:
                current_priority = action["priority"]
                f.write("\n")
                f.write("#" * 120 + "\n")
                f.write(f"{current_priority.upper()} PRIORITY MATCHES\n")
                f.write("#" * 120 + "\n\n")

            f.write("=" * 120 + "\n")
            f.write(f"ACTION #{idx}\n")
            f.write("=" * 120 + "\n")
            f.write(f"Priority: {action['priority']}\n")
            f.write(f"Source: {action['source']}\n")
            f.write(f"Date: {action['date']}\n")
            f.write(f"From: {action['from_name']} <{action['from_email']}>\n")
            f.write(f"To: {action['to']}\n")

            if action["cc"]:
                f.write(f"Cc: {action['cc']}\n")

            f.write(f"Subject: {action['subject']}\n")
            f.write("\n")
            f.write("Possible action:\n")
            f.write(action["action_text"])
            f.write("\n\n")

    return len(deduped)


def main():
    os.makedirs(OUTPUT_FOLDER, exist_ok=True)

    cutoff = datetime.now() - timedelta(days=DAYS_BACK)
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M")

    output_file = os.path.join(
        OUTPUT_FOLDER,
        f"actions for Michal {timestamp}.txt"
    )

    print("Connecting to Outlook...")

    outlook = win32com.client.Dispatch("Outlook.Application")
    namespace = outlook.GetNamespace("MAPI")

    received_actions = scan_folder(namespace, OL_FOLDER_INBOX, "Received", cutoff)
    sent_actions = scan_folder(namespace, OL_FOLDER_SENT_MAIL, "Sent", cutoff)

    all_actions = received_actions + sent_actions

    print()
    print(f"Total possible action lines before deduplication: {len(all_actions)}")

    count_after = write_report(all_actions, output_file, cutoff)

    print(f"Total possible action lines after deduplication: {count_after}")
    print()
    print("Done.")
    print("Saved file here:")
    print(output_file)


if __name__ == "__main__":
    main()