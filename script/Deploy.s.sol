// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.33;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {WrappedDMD} from "src/WrappedDMD.sol";

interface ICreateX {
    function deployCreate2(bytes32 salt, bytes memory initCode) external payable returns (address);
    function computeCreate2Address(bytes32 salt, bytes32 initCodeHash) external view returns (address);
}

contract WrappedDMDDeploy is Script {
    ICreateX public createx = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    function deploy(uint256 deployerPk) public returns (address) {
        vm.startBroadcast(deployerPk);

        WrappedDMD wdmd = new WrappedDMD();

        vm.stopBroadcast();

        return address(wdmd);
    }

    function deployCreate2(uint256 deployerPk) public returns (address) {
        address deployer = vm.addr(deployerPk);

        bytes32 salt = bytes32(abi.encodePacked(bytes20(deployer), hex"00", bytes11(keccak256("wrapped dmd"))));
        console.logBytes32(salt);

        bytes memory initCode = type(WrappedDMD).creationCode;

        vm.startBroadcast(deployerPk);

        address deployed = createx.deployCreate2(salt, initCode);

        vm.stopBroadcast();

        return deployed;
    }

    function run() public {
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");

        address wdmd = deployCreate2(deployerPk);

        console.log("Wrapped DMD address: ", wdmd);
    }
}
