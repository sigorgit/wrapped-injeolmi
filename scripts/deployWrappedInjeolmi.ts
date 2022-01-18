import hardhat from "hardhat";

async function main() {
    console.log("deploy start")

    const WrappedInjeolmi = await hardhat.ethers.getContractFactory("WrappedInjeolmi")
    const wijm = await WrappedInjeolmi.deploy("0x5307B5E725feB3D6A55605daC1986e3571FB765D")
    console.log(`WrappedInjeolmi address: ${wijm.address}`)
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
