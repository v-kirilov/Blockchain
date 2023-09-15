task("deploy", "Prints an account's balance")
    .addParam("account", "The accounts's address")
    .setAction(async (taskAsrgs, hre) => {
        const [deployer] = await hre.ethers.getSigners();
        const CrowdFundingFactory = await hre.ethers.getContractFactory("CrowdFunding", deployer);
        const goal = hre.ethers.utils.parseEther("20");

        const crowdFunding = await CrowdFundingFactory.deploy(
            0,
            "MyNewCF",
            "For charity work",
            goal,
            3600);

        await crowdFunding.deployed();

        console.log(
            `CrowdFunding with ${deployer.address} deployed to ${crowdFunding.address}`
        );
        console.log(taskAsrgs.account)
    });


task("contribute", "Task for contribute mechanism")
    .addParam("crowdfunding", "The contract's address")
    .setAction(async (taskAsrgs, hre) => {
        const [deployer, firstUser] = await hre.ethers.getSigners();
        const CrowdFundingFactory = await hre.ethers.getContractFactory(
            "CrowdFunding",
            deployer
        );
        const crowdfunding = new hre.ethers.Contract(
            taskAsrgs.crowdfunding,
            CrowdFundingFactory.interface,
            deployer
        );

        const cfFirstUser = crowdfunding.connect(firstUser);
        const firstContribution = ethers.utils.parseEther("1");

        const tx = await cfFirstUser.contribute({ value: firstContribution });
        const receipt = await tx.wait();
        if (receipt.status === 0) {
            throw new Error("Tx failed!")
        }

        console.log(`${cfFirstUser.address} has contributed!`)
    });


//npx hardhat deploy --account tests --network sepolia
//npx hardhat verify --network sepolia --constructor-args arguments.js 0x8849Db5A8046f8AaFCEE172Af231B0f229187843

//npx hardhat deploy --account testt --network localhost
//npx hardhat contribute --crowdfunding testtt --network localhost

//The addres that I've already deployed the contract with the "deploy task"
//npx hardhat contribute2 --crowdfunding 0xe7f1725e7734ce288f8367e1bb143e90bb3f0512 --network localhost