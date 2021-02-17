# Treasury

These are the contracts for Beluga Protocol's high yield treasury. This treasury takes a modular approach that allows logic to be added to the Treasury contract which acts as the control over the whole treasury system. These modules allow for extra logic to be added to the treasury and can allow for all kinds of yield-generating strategies. Each module is ran behind a proxy for max efficiency. 

For modules to function, governance adds them to a built-in registry on the Treasury contract, from there, governance can allocate however many funds to any module. The goal for this treasury to maximize the earning potential of protocol profits to allow for larger buybacks and more funding for the community.