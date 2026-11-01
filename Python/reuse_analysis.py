
import csv
import os
from collections import Counter

TRACE_DIR = "traces"

def load_addresses(filename):
    addresses = []

    with open(filename, "r") as f:
        reader = csv.DictReader(f)

        for row in reader:
            addresses.append(int(row["address"], 16))

    return addresses


def reuse_distance_analysis(addresses, line_size=16):

    # Convert byte addresses into cache-line addresses
    lines = [addr // line_size for addr in addresses]

    last_seen = {}
    distances = []

    for i, line in enumerate(lines):

        if line in last_seen:

            previous = last_seen[line]

            # Count distinct cache lines accessed since previous use
            distance = len(set(lines[previous+1:i]))

            distances.append(distance)

        else:
            distances.append(None)

        last_seen[line] = i

    valid = [d for d in distances if d is not None]

    print("\nREUSE DISTANCE")
    print("Total accesses:", len(lines))
    print("First-time line accesses:", distances.count(None))
    print("Reused line accesses:", len(valid))

    if valid:
        print("Average reuse distance:",
              round(sum(valid) / len(valid), 2))

        print("Maximum reuse distance:", max(valid))

        print("Reuse distance distribution:")
        print(Counter(valid).most_common(10))


def working_set_analysis(addresses, line_size=16, window=16):

    lines = [addr // line_size for addr in addresses]

    working_sets = []

    for i in range(len(lines)):

        start = max(0, i - window + 1)

        recent = lines[start:i+1]

        working_sets.append(len(set(recent)))

    print("\nWORKING SET ANALYSIS")
    print("Window size:", window, "accesses")
    print("Maximum working set:",
          max(working_sets), "cache lines")

    print("Average working set:",
          round(sum(working_sets) / len(working_sets), 2),
          "cache lines")


for filename in sorted(os.listdir(TRACE_DIR)):

    if not filename.endswith(".csv"):
        continue

    print("\n" + "=" * 55)
    print("TRACE:", filename)
    print("=" * 55)

    addresses = load_addresses(
        os.path.join(TRACE_DIR, filename)
    )

    print("\n--- 16-byte cache lines ---")

    reuse_distance_analysis(addresses, 16)

    working_set_analysis(
        addresses,
        line_size=16,
        window=16
    )
