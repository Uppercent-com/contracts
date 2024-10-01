pragma solidity ^0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ILayerZeroComposer } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";

import { IBlazeSwapRouter } from "@blazeswap/contracts/contracts/periphery/interfaces/IBlazeSwapRouter.sol";

contract ComposerReceiverBlazeswap is ILayerZeroComposer {
    IBlazeSwapRouter public immutable blazeswapRouter;
    address public immutable endpoint;
    address public immutable stargate;

    event ReceivedOnDestination(address token);

    constructor(address _blazeswapRouter, address _endpoint, address _stargate) {
        blazeswapRouter = IBlazeSwapRouter(_blazeswapRouter);
        endpoint = _endpoint;
        stargate = _stargate;
    }

    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable {
        require(_from == stargate, "!stargate");
        require(msg.sender == endpoint, "!endpoint");

        uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);
        bytes memory _composeMessage = OFTComposeMsgCodec.composeMsg(_message);

        (address _tokenReceiver, address _oftOnDestination, address _tokenOut, uint _amountOutMinDest, uint _deadline) =
            abi.decode(_composeMessage, (address, address, address, uint, uint));

        address[] memory path = new address[](2);
        path[0] = _oftOnDestination;
        path[1] = _tokenOut;

        IERC20(_oftOnDestination).approve(address(blazeswapRouter), amountLD);

        try blazeswapRouter.swapExactTokensForNAT(
            amountLD,
            _amountOutMinDest,
            path,  
            _tokenReceiver, 
            _deadline 
        ) {
            emit ReceivedOnDestination(_tokenOut);
        } catch {
            IERC20(_oftOnDestination).transfer(_tokenReceiver, amountLD);
            emit ReceivedOnDestination(_oftOnDestination);
        }
    }

    fallback() external payable {}
    receive() external payable {}
}
