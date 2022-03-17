from typing import Iterable

from tests.support.quantized_decimal import QuantizedDecimal as D

EPSILON = 0.005


def twap_clustering(prices: Iterable[D]) -> D:
    sorted_prices = prices.sort()
    diff_sorted_prices = [
        sorted_prices[i + 1] - sorted_prices[i] for i in range(len(sorted_prices) - 1)
    ]
    cluster = [0 for i in prices]
    current_cluster = 0
    for i in range(len(diff_sorted_prices)):
        if diff_sorted_prices[i] < EPSILON:
            cluster[i + 1] = current_cluster
        elif i == len(diff_sorted_prices) - 1:
            cluster[i + 1] = current_cluster + 1
        else:
            current_cluster += 1

    cluster_counts = [0 for i in prices]
    for clus in cluster:
        cluster_counts[clus] += 1

    cluster_counts.argmax()

    # choose the biggest cluster
    # handle if there are multiple of same size >1
    # handle if all of size 1
