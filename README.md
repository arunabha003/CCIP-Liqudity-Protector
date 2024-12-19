Liqudity Chain -> Chain where all the funds are kept -> Arbritum -> Aave V3
Debt Chain -> Chain where a debt position has occured -> Ethereum Mainnet -> CompoundV2
MonitorCompoundV2.sol should be deployed on the Debt Chain
LPSC.sol should be deployed in the Liqudity Chain 



To do:
1. approve should be done for the GasFee token allownace inside the MonitorCompoundV2.sol constructor not in the test
2.Learn about the vm.mockCall in the tests.