
contract MockBean3Curve {
    uint256 a;
    uint256[2] balances;
    uint256 supply;

    function A_precise() external view returns (uint256) {
        return a;
    }
    function get_balances() external view returns (uint256[2] memory) {
        return balances;
    }
    function totalSupply() external view returns (uint256) {
        return supply;
    }

    function set_A_precise(uint256 _a) external {
        a = _a;
    }

    function set_balances(uint256[2] memory _balances) external {
        balances = _balances;
    }

    function set_supply(uint256 _supply) external {
        supply = _supply;
    }
}