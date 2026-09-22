"""Fetch upcoming CalDAV events and write them as JSON for the Quickshell bar.

Usage: agenda.py OUTPUT_JSON
CALDAV_ACCOUNTS names the accounts; each NAME has CALDAV_NAME_URL,
CALDAV_NAME_USERNAME and CALDAV_NAME_PASSWORD in the environment, and an
optional CALDAV_NAME_CALENDARS JSON list restricting it to those calendar
names. An account that fails keeps its rows from the previous output, and
the exit status reports the failure so the bar can flag it.
"""

import json
import os
import re
import sys
import tempfile
from datetime import date, datetime, timedelta

import caldav

PAST_DAYS = 14
FUTURE_DAYS = 60
DESCRIPTION_LIMIT = 500

# Video call providers, matched inside URLs. The link itself is the join action.
MEETING_HOSTS = (
    r"zoom\.us/(j|my|w)/|meet\.google\.com/|teams\.microsoft\.com/l/meetup-join"
    r"|teams\.live\.com/meet|meet\.jit\.si/|jitsi|whereby\.com/|webex\.com/"
    r"|bigbluebutton|/bbb/|meet\.goto\.com|gotomeet\.me|discord\.gg/|discord\.com/"
    r"|around\.co/|livestorm\.co/|streamyard\.com/|meet\.zoom\.us"
)
URL = re.compile(r"""https?://[^\s<>"']+""")
MEETING_URL = re.compile(r"""https?://[^\s<>"']*(?:%s)[^\s<>"']*""" % MEETING_HOSTS, re.I)

# Properties calendar clients use to carry the conference link.
MEETING_PROPERTIES = (
    "X-GOOGLE-CONFERENCE",
    "X-MICROSOFT-SKYPETEAMSMEETINGURL",
    "X-MICROSOFT-ONLINEMEETINGEXTERNALLINK",
    "CONFERENCE",
    "URL",
)

LOCAL_TZ = datetime.now().astimezone().tzinfo


def text(component, name):
    value = component.get(name)
    return "" if value is None else str(value).strip()


def clean_url(url):
    return url.rstrip(".,;:)>]}'\"")


def meeting_link(component):
    for name in MEETING_PROPERTIES:
        match = MEETING_URL.search(text(component, name))
        if match:
            return clean_url(match.group(0))
    for name in ("LOCATION", "DESCRIPTION"):
        match = MEETING_URL.search(text(component, name))
        if match:
            return clean_url(match.group(0))
    return None


def event_link(component):
    for name in ("URL", "LOCATION", "DESCRIPTION"):
        match = URL.search(text(component, name))
        if match:
            return clean_url(match.group(0))
    return None


def as_datetime(value):
    """Normalise floating and zoned datetimes to the local zone."""
    if value.tzinfo is None:
        return value.replace(tzinfo=LOCAL_TZ)
    return value.astimezone(LOCAL_TZ)


def span(component):
    start = component.decoded("DTSTART")
    all_day = not isinstance(start, datetime)

    if "DTEND" in component:
        end = component.decoded("DTEND")
    elif "DURATION" in component:
        end = start + component.decoded("DURATION")
    else:
        end = start + timedelta(days=1) if all_day else start

    if all_day:
        return start.isoformat(), end.isoformat(), True
    return as_datetime(start).isoformat(), as_datetime(end).isoformat(), False


def describe(component, account, calendar):
    start, end, all_day = span(component)
    description = text(component, "DESCRIPTION")
    if len(description) > DESCRIPTION_LIMIT:
        description = description[:DESCRIPTION_LIMIT].rstrip() + "…"

    return {
        "uid": text(component, "UID"),
        "account": account,
        "calendar": calendar,
        "summary": text(component, "SUMMARY") or "(untitled)",
        "start": start,
        "end": end,
        "allDay": all_day,
        "location": text(component, "LOCATION"),
        "description": description,
        "url": event_link(component),
        "meeting": meeting_link(component),
    }


def collect(components, account, calendar):
    """Turn VEVENT components into agenda rows, dropping cancellations and duplicates."""
    rows = {}
    for component in components:
        if component.name != "VEVENT" or "DTSTART" not in component:
            continue
        if text(component, "STATUS").upper() == "CANCELLED":
            continue
        row = describe(component, account, calendar)
        rows[(row["uid"], row["start"])] = row
    return list(rows.values())


def fetch(account):
    prefix = "CALDAV_%s_" % account.upper()
    url = os.environ[prefix + "URL"]
    username = os.environ[prefix + "USERNAME"]
    password = os.environ[prefix + "PASSWORD"]
    wanted = json.loads(os.environ.get(prefix + "CALENDARS") or "null")

    today = date.today()
    start = datetime.combine(today - timedelta(days=PAST_DAYS), datetime.min.time())
    end = datetime.combine(today + timedelta(days=FUTURE_DAYS), datetime.min.time())

    events = []
    with caldav.DAVClient(url=url, username=username, password=password) as client:
        for calendar in client.principal().calendars():
            name = str(calendar.get_display_name() or "")
            if wanted is not None and name not in wanted:
                continue
            found = calendar.search(start=start, end=end, event=True, expand=True)
            components = (
                component
                for resource in found
                for component in resource.icalendar_instance.walk("VEVENT")
            )
            events.extend(collect(components, account, name))
    return events


def previous(path):
    try:
        with open(path) as handle:
            return json.load(handle).get("events", [])
    except (OSError, ValueError):
        return []


def fetch_all(accounts, path):
    """Fetch every account, falling back to the last output for any that fails."""
    events = []
    failed = []
    for account in accounts:
        try:
            events.extend(fetch(account))
        except Exception as error:  # noqa: BLE001 - any failure keeps the old rows
            print("%s: %s" % (account, error), file=sys.stderr)
            failed.append(account)

    if failed:
        events.extend(row for row in previous(path) if row.get("account") in failed)

    events.sort(key=lambda row: (row["start"], row["summary"]))
    return events, failed


def write(path, payload):
    directory = os.path.dirname(path) or "."
    os.makedirs(directory, exist_ok=True)
    handle, temporary = tempfile.mkstemp(dir=directory, prefix=".agenda-")
    with os.fdopen(handle, "w") as out:
        json.dump(payload, out)
    os.replace(temporary, path)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    accounts = os.environ["CALDAV_ACCOUNTS"].split()
    path = sys.argv[1]

    events, failed = fetch_all(accounts, path)
    if len(failed) == len(accounts):
        sys.exit(1)

    write(path, {"synced": datetime.now(LOCAL_TZ).isoformat(), "events": events})
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
