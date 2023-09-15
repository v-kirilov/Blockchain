task("deploy", "Prints the address")
    .addParam("account", "The organization's address")
    .setAction(async (taskAsrgs, hre) => {
        const [deployer] = await hre.ethers.getSigners();
        const TreasuryFactory = await hre.ethers.getContractFactory("Organization", deployer);

        const treasury = await TreasuryFactory.deploy();
        await treasury.deployed();

        console.log(
            `Treasury with ${deployer.address} deployed to ${treasury.address}`
        );
        console.log(taskAsrgs.account);
    });

    task("store", "Prints the address")
    .addParam("account", "The organization's address")
    .setAction(async (taskAsrgs, hre) => {
        const [deployer,firstUser] = await hre.ethers.getSigners();
        const TreasuryFactory = await hre.ethers.getContractFactory("Organization", deployer);

        const treasury = await TreasuryFactory.deploy();
        await treasury.deployed();

        const _firstUser = treasury.connect(firstUser);
        const originalUser = treasury.connect(deployer);
        await originalUser.createTreasury();
        
        _firstUser.storeFunds(0,{ value: 1000 })

        console.log(
            `Funds stored by ${_firstUser.address}`
        );
        console.log(taskAsrgs.account);
    });

    //Поради някаква причина не разпознава .deployed() което е някакъв абсурд.
    //Има ъпдейт на хардхат и туулбокса , като нищо може и от там да е проблема.
    //Аз не виждам тук проблем.

    //ДА ето я грешката 
    //https://ethereum.stackexchange.com/questions/151233/typeerror-no-matching-function-argument-key-value-deployed-code-invalid

    //Ползвам по-старите версии за да могат да работят тасковете и да мога да диплйна контракта на Sepolia

    