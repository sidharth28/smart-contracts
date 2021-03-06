pragma solidity ^0.5.0;

import "./zeppelin/math/SafeMath.sol";
import "./SnowflakeResolver.sol";
import "./interfaces/IdentityRegistryInterface.sol";
import "./interfaces/HydroInterface.sol";
import "./interfaces/SnowflakeInterface.sol";
import "./interfaces/ClientRaindropInterface.sol";
import "./ProtectedWallet.sol";

 /**
   1. Wallet allows the owning hydroId or any whitelisted address
   to deposit hydro tokens freely
   2. Upon wallet creation, the hydroId specifies the token withdrawal
   daily limit.  This daily limit does not accumulate.
   3. The wallet includes the option to do an unlimited withdrawal after
   going through 2FA facilitated by the chainlink external adapter
   4. In case the chainlink node and/or the hydrogen api. are not operational
   there exists a one time use password recovery option.  This one time use password
   deposits all of the hydro tokens into the calling address and terminates the
   wallet.
  */

  //1. Get the contracts working with ein -- done
  //2. Get deposits and withdrawals working with snowflake -- done
  //3. Get deposits and withdrawals working w/external addresses -- done
  //4. Commit reveal recovery working -- done


contract ProtectedWalletFactory is SnowflakeResolver {
    using SafeMath for uint;
    
    IdentityRegistryInterface idRegistry;
    SnowflakeInterface        snowflake;
    ClientRaindropInterface   clientRaindrop;

    mapping (uint => address) private einToWallet;
    mapping (uint => bool) private    einHasDeleted;
    mapping (address => bool) private isHydroIdAddress;
    mapping (uint => string) private  einToHydroId;

    uint signUpFee =          1 ether;
    uint standardDailyLimit = 1000 ether;
    bytes32 defaultPass =     0xFFFFFFFFFFFFFFFFFFFFFFFFFFF0000000000000000000000000000000000000;

    modifier onlyWallet(uint ein) {
        require(msg.sender == einToWallet[ein], "Only the wallet affiliated with this ein can call this function");
        _;
    }

    constructor(address snowflakeAddress, address clientRaindropAddr) 
    SnowflakeResolver("Protected wallet factory", "Generate your unique protected wallet", snowflakeAddress, true, true)
    public {
        setClientRaindropAddress(clientRaindropAddr);
        setSnowflakeAddress(snowflakeAddress);
    }

    function onAddition(uint ein, uint, bytes memory extraData) public senderIsSnowflake() returns (bool) {
        (address hydroAddr, string memory hydroId) = clientRaindrop.getDetails(ein);
        isHydroIdAddress[hydroAddr] = true;
        einToHydroId[ein] = hydroId;
        address wallet = createWallet(ein);
        einToWallet[ein] = wallet;
        return true;
    }

    function setClientRaindropAddress(address clientRaindropAddr) public onlyOwner() {
        clientRaindrop = ClientRaindropInterface(clientRaindropAddr);
    }

    function setSnowflakeAddress(address _snowflakeAddress) public onlyOwner() {
        super.setSnowflakeAddress(_snowflakeAddress);
        snowflake = SnowflakeInterface(snowflakeAddress);
        idRegistry = IdentityRegistryInterface(snowflake.identityRegistryAddress());
    }

    function onRemoval(uint, bytes memory) public senderIsSnowflake() returns (bool) {
        return true;
    }
    
    // For use after an ein has registered with this resolver, but has deleted
    // one or more wallets
    function generateNewWallet(uint ein, bytes memory) public returns (address) {
        require(ein == idRegistry.getEIN(msg.sender), "Only an associated address can generate a new wallet");
        require(einHasDeleted[ein] == true, "Ein must have deleted the previous wallet");
        address wallet = createWallet(ein);
        einToWallet[ein] = wallet;
        return wallet;
    } 

    function createWallet(uint ein) internal returns (address) {
        ProtectedWallet protectedWallet = new ProtectedWallet(ein, standardDailyLimit, address(snowflake), address(clientRaindrop));
        return address(protectedWallet);
    }

    function deleteWallet(uint ein) public onlyWallet(ein) returns (bool) {
        delete einToWallet[ein];
        einHasDeleted[ein] = true;
        return true;
    }

    function getWalletByEIN(uint ein) public view returns (address) {
        return einToWallet[ein];
    }

    function getWalletByAddress(address addr) public view returns (address) {
        uint _ein = idRegistry.getEIN(addr);
        return getWalletByEIN(_ein);
    }

    function getSnowflakeAddress() public view returns (address) {
        return snowflakeAddress;
    }

}