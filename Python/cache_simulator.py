
import csv
import os
from collections import OrderedDict

TRACE_DIR = "traces"
RESULT_DIR = "results"

LINE_SIZE = 16

CAPACITIES = [256, 512, 1024, 2048]
ASSOCIATIVITIES = [1, 2, 4, "FULL"]

os.makedirs(RESULT_DIR, exist_ok=True)


def load_trace(filename):

    addresses = []

    with open(filename, "r") as f:
        reader = csv.DictReader(f)

        for row in reader:
            addresses.append(int(row["address"], 16))

    return addresses


class Cache:

    def __init__(self, capacity, line_size, associativity):

        self.num_lines = capacity // line_size

        if associativity == "FULL":
            self.ways = self.num_lines
        else:
            self.ways = associativity

        self.num_sets = self.num_lines // self.ways

        # Each set stores lines in LRU order.
        # First entry = least recently used.
        self.sets = [
            OrderedDict()
            for _ in range(self.num_sets)
        ]

    def access(self, address):

        line_addr = address // LINE_SIZE

        set_index = line_addr % self.num_sets
        tag = line_addr // self.num_sets

        cache_set = self.sets[set_index]

        if tag in cache_set:

            # Hit: move to most recently used position
            cache_set.move_to_end(tag)

            return True

        # Miss
        if len(cache_set) >= self.ways:

            # Evict least recently used line
            cache_set.popitem(last=False)

        cache_set[tag] = True

        return False


def simulate(addresses, capacity, associativity):

    target_cache = Cache(
        capacity, LINE_SIZE, associativity
    )

    shadow_cache = Cache(
        capacity, LINE_SIZE, "FULL"
    )

    seen_lines = set()

    hits = 0
    compulsory = 0
    conflict = 0
    capacity_misses = 0

    for address in addresses:

        line_addr = address // LINE_SIZE

        # Actual cache
        target_hit = target_cache.access(address)

        # Fully associative LRU reference cache
        shadow_hit = shadow_cache.access(address)

        if target_hit:

            hits += 1

        else:

            if line_addr not in seen_lines:
                compulsory += 1

            elif shadow_hit:
                conflict += 1

            else:
                capacity_misses += 1

        seen_lines.add(line_addr)

    total = len(addresses)
    misses = total - hits

    return {
        "hits": hits,
        "misses": misses,
        "compulsory": compulsory,
        "conflict": conflict,
        "capacity": capacity_misses,
        "hit_rate": 100 * hits / total,
        "miss_rate": 100 * misses / total
    }


def main():

    all_results = []

    for filename in sorted(os.listdir(TRACE_DIR)):

        if not filename.endswith(".csv"):
            continue

        addresses = load_trace(
            os.path.join(TRACE_DIR, filename)
        )

        print("\n" + "=" * 85)
        print("TRACE:", filename)
        print("=" * 85)

        print(
            f"{'Capacity':>9} | {'Ways':>5} | "
            f"{'Hits':>5} | {'Misses':>6} | "
            f"{'Comp.':>5} | {'Conf.':>5} | "
            f"{'Cap.':>5} | {'Hit %':>8}"
        )

        for capacity in CAPACITIES:

            for assoc in ASSOCIATIVITIES:

                result = simulate(
                    addresses,
                    capacity,
                    assoc
                )

                ways = (
                    "FULL" if assoc == "FULL"
                    else str(assoc)
                )

                capacity_label = (
                    f"{capacity} B"
                )

                row = {
                    "trace": filename,
                    "capacity_bytes": capacity,
                    "associativity": ways,
                    **result
                }

                all_results.append(row)

                print(
                    f"{capacity_label:>9} | "
                    f"{ways:>5} | "
                    f"{result['hits']:5d} | "
                    f"{result['misses']:6d} | "
                    f"{result['compulsory']:5d} | "
                    f"{result['conflict']:5d} | "
                    f"{result['capacity']:5d} | "
                    f"{result['hit_rate']:7.2f}%"
                )

    output_file = os.path.join(
        RESULT_DIR,
        "cache_comparison.csv"
    )

    with open(output_file, "w", newline="") as f:

        writer = csv.DictWriter(
            f,
            fieldnames=all_results[0].keys()
        )

        writer.writeheader()
        writer.writerows(all_results)

    print("\nResults saved to:", output_file)


if __name__ == "__main__":
    main()
