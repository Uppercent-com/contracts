pragma solidity ^0.8.19;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ILayerZeroComposer } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";

import { IBlazeSwapRouter } from "@blazeswap/contracts/contracts/periphery/interfaces/IBlazeSwapRouter.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract ComposerReceiverBlazeswap is ILayerZeroComposer, Ownable {
    using SafeERC20 for IERC20;
    IBlazeSwapRouter public immutable blazeswapRouter;
    address public immutable endpoint;
    address[3] public stargateAddresses;

    event ReceivedOnDestination(address token);

    constructor(
        address _blazeswapRouter, 
        address _endpoint, 
        address[3] memory _stargateAddresses
    ) Ownable(msg.sender) {
        blazeswapRouter = IBlazeSwapRouter(_blazeswapRouter);
        endpoint = _endpoint;
        stargateAddresses = _stargateAddresses;
    }

    function isStargateAddress(address _from) internal view returns (bool) {
        for (uint i = 0; i < stargateAddresses.length; i++) {
            if (_from == stargateAddresses[i]) {
                return true;
            }
        }
        return false;
    }

    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable {
        require(isStargateAddress(_from), "!stargate");
        require(msg.sender == endpoint, "!endpoint");

        uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);
        bytes memory _composeMessage = OFTComposeMsgCodec.composeMsg(_message);

        (address _tokenReceiver, address _oftOnDestination, address _tokenOut, uint _amountOutMinDest, uint _deadline) =
            abi.decode(_composeMessage, (address, address, address, uint, uint));

        address[] memory path = new address[](2);
        path[0] = _oftOnDestination;
        path[1] = _tokenOut;

        IERC20(_oftOnDestination).approve(address(blazeswapRouter), 0);
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
            IERC20(_oftOnDestination).safeTransfer(_tokenReceiver, amountLD);
            emit ReceivedOnDestination(_oftOnDestination);
        }
    }

    function adminWithdrawTokens(address _token, uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than zero");
        IERC20(_token).safeTransfer(owner(), _amount);
    }

    fallback() external payable {}
    receive() external payable {}
}
