task("deploy", "Prints an account's balance")
    .addParam("account", "The accounts's address")
    .setAction(async (taskAsrgs, hre) => {
        const [deployer] = await hre.ethers.getSigners();
        const CharityCampaignFactory = await hre.ethers.getContractFactory("CharityCampaign", deployer);

        const charityCamp = await CharityCampaignFactory.deploy();

        await charityCamp.deployed();

        console.log(
            `Campaign with owner:${deployer.address}, deployed to ${charityCamp.address}`
        );
        console.log(taskAsrgs);
    });
    //npx hardhat deploy --account tests --network sepolia
    //npx hardhat verify --network sepolia 0xeC665842FD8aB1613f0DB843bEb98Ffc9E5ed50B

task("createCampaign", "Prints an account's balance")
    .addParam("account", "The accounts's address")
    .setAction(async (taskAsrgs, hre) => {
        const [deployer, firstUser] = await hre.ethers.getSigners();

        const CharityCampaignFactory = await hre.ethers.getContractFactory("CharityCampaign", deployer);
        const charityCamp = await CharityCampaignFactory.deploy();
        await charityCamp.deployed();

        const _firstUser = charityCamp.connect(firstUser)
        const goal = hre.ethers.utils.parseEther("20");

        const tx = await _firstUser.createCampaign("First", "My first campaign", goal, 3600);
        const campaign =await _firstUser.campaigns(0);

        console.log(
            `Campaign with id:${campaign.id} and goal: ${campaign.goal} created!`
        );
        console.log(taskAsrgs);
    });