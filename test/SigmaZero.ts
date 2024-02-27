import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("SigmaZero", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployOneYearSigmaZeroFixture() {
    const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;

    // Contracts are deployed using the first signer/account by default
    const [owner, betInitiator, secondBettor, thirdBettor, fourthBettor] =
      await ethers.getSigners();

    const SigmaZero = await ethers.getContractFactory("SigmaZero");
    const sigmaZero = await SigmaZero.deploy();

    return {
      sigmaZero,
      owner,
      betInitiator,
      secondBettor,
      thirdBettor,
      fourthBettor,
      ONE_YEAR_IN_SECS,
    };
  }

  describe("Deployment", function () {
    it("Should set the right admin", async function () {
      const { sigmaZero, owner } = await loadFixture(
        deployOneYearSigmaZeroFixture
      );

      expect(
        await sigmaZero.hasRole(
          await sigmaZero.DEFAULT_ADMIN_ROLE(),
          owner.address
        )
      ).to.equal(true);
    });
  });

  describe("Creating Bets", function () {
    it("Should allow user to create a bet", async function () {
      const { sigmaZero, betInitiator } = await loadFixture(
        deployOneYearSigmaZeroFixture
      );

      await sigmaZero
        .connect(betInitiator)
        .placeBet(
          "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe",
          10,
          2,
          1000000000000000000n,
          {
            value: ethers.parseEther("1"),
          }
        );

      const bet = await sigmaZero.bets(1);
      const firstBettor = await sigmaZero.firstBettorsGroupByBetIndex(1, 0);
      expect(bet.duration).to.equal(10);
      expect(firstBettor.wager).to.equal(1000000000000000000n);
    });

    it("Should emit an event when a bet is placed", async function () {
      const { sigmaZero, betInitiator } = await loadFixture(
        deployOneYearSigmaZeroFixture
      );

      await expect(
        sigmaZero
          .connect(betInitiator)
          .placeBet(
            "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe",
            10,
            2,
            1000000000000000000n,
            {
              value: ethers.parseEther("1"),
            }
          )
      )
        .to.emit(sigmaZero, "BetPlaced")
        .withArgs(
          betInitiator.address,
          "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe",
          2,
          1000000000000000000n,
          10,
          1
        );
    });

    it("Should allow user to create a bet with a duration of 100 years", async function () {
      const { sigmaZero, ONE_YEAR_IN_SECS, betInitiator } = await loadFixture(
        deployOneYearSigmaZeroFixture
      );

      await sigmaZero
        .connect(betInitiator)
        .placeBet(
          "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe",
          100 * ONE_YEAR_IN_SECS,
          2,
          1000000000000000000n,
          {
            value: ethers.parseEther("1"),
          }
        );

      const bet = await sigmaZero.bets(1);
      const firstBettor = await sigmaZero.firstBettorsGroupByBetIndex(1, 0);
      expect(bet.duration).to.equal(100 * ONE_YEAR_IN_SECS);
      expect(firstBettor.wager).to.equal(1000000000000000000n);
    });

    it("Should allow the user to wager 1000000 ETH", async function () {
      const { sigmaZero, owner, betInitiator } = await loadFixture(
        deployOneYearSigmaZeroFixture
      );

      await sigmaZero
        .connect(betInitiator)
        .placeBet(
          "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe",
          10,
          2,
          1000000000000000000000000n,
          {
            value: ethers.parseEther("1000000"),
          }
        );

      const bet = await sigmaZero.bets(1);
      const firstBettor = await sigmaZero.firstBettorsGroupByBetIndex(1, 0);
      expect(firstBettor.wager).to.equal(1000000000000000000000000n);
    });

    it("Should allow the admin to set the bet value", async function () {
      const { sigmaZero, owner, betInitiator } = await loadFixture(
        deployOneYearSigmaZeroFixture
      );

      await sigmaZero
        .connect(betInitiator)
        .placeBet(
          "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe",
          10,
          2,
          1000000000000000000n,
          {
            value: ethers.parseEther("1"),
          }
        );
      await sigmaZero.connect(owner).setBetValue(1, 2000, Date.now());

      const bet = await sigmaZero.bets(1);
      expect(bet.value).to.equal(2000);
      expect(bet.status).to.equal(1);
    });

    it("Should throw an error if the bet doesn't exist", async function () {
      const { sigmaZero, owner, betInitiator } = await loadFixture(
        deployOneYearSigmaZeroFixture
      );

      await expect(
        sigmaZero.connect(owner).setBetValue(1, 2000, Date.now())
      ).to.be.revertedWith("Bet does not exist");
    });

    it("Should not allow the bet initiator to set the bet value", async function () {
      const { sigmaZero, owner, betInitiator } = await loadFixture(
        deployOneYearSigmaZeroFixture
      );

      await sigmaZero
        .connect(betInitiator)
        .placeBet(
          "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe",
          10,
          2,
          1000000000000000000n,
          {
            value: ethers.parseEther("1"),
          }
        );
      await expect(
        sigmaZero.connect(betInitiator).setBetValue(1, 2000, Date.now())
      ).to.be.revertedWith("Caller is not an admin");
    });

    it("Should not allow the admin to set the value of an already approved bet", async function () {
      const { sigmaZero, owner, betInitiator } = await loadFixture(
        deployOneYearSigmaZeroFixture
      );

      await sigmaZero
        .connect(betInitiator)
        .placeBet(
          "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe",
          10,
          2,
          1000000000000000000n,
          {
            value: ethers.parseEther("1"),
          }
        );
      await sigmaZero.connect(owner).setBetValue(1, 2000, Date.now());
      await expect(
        sigmaZero.connect(owner).setBetValue(1, 2000, Date.now())
      ).to.be.revertedWith("Bet is already approved");
    });

    it("Should not allow bettor to add themselves to bet if the bet isn't approved", async function () {
      const { sigmaZero, owner, betInitiator } = await loadFixture(
        deployOneYearSigmaZeroFixture
      );

      await sigmaZero
        .connect(betInitiator)
        .placeBet(
          "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe",
          10,
          2,
          1000000000000000000n,
          {
            value: ethers.parseEther("1"),
          }
        );
      await expect(
        sigmaZero.connect(owner).addBettor(1, 2, 2000000000000000000n, {
          value: ethers.parseEther("2"),
        })
      ).to.be.revertedWith("Bet is not approved");
    });

    it("Should allow bettor to add themselves to bet", async function () {
      const { sigmaZero, owner, betInitiator, secondBettor } =
        await loadFixture(deployOneYearSigmaZeroFixture);

      await sigmaZero
        .connect(betInitiator)
        .placeBet(
          "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe",
          10,
          2,
          1000000000000000000n,
          {
            value: ethers.parseEther("1"),
          }
        );
      await sigmaZero.connect(owner).setBetValue(1, 2000, Date.now());
      await sigmaZero
        .connect(secondBettor)
        .addBettor(1, 2, 2000000000000000000n, {
          value: ethers.parseEther("2"),
        });

      const firstAddedBettor = await sigmaZero.secondBettorsGroupByBetIndex(
        1,
        0
      );
      expect((await sigmaZero.bets(1)).secondBettorsGroupPool).to.equal(
        2000000000000000000n
      );
      expect(firstAddedBettor.wager).to.equal(2000000000000000000n);
    });

    it("Should allow the admin to close the bet", async function () {
      const { sigmaZero, owner, betInitiator } = await loadFixture(
        deployOneYearSigmaZeroFixture
      );

      await sigmaZero
        .connect(betInitiator)
        .placeBet(
          "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe",
          10,
          2,
          1000000000000000000n,
          {
            value: ethers.parseEther("1"),
          }
        );
      await sigmaZero.connect(owner).setBetValue(1, 2000, Date.now());
      await sigmaZero.connect(owner).closeBet(1);

      const bet = await sigmaZero.bets(1);
      expect(bet.status).to.equal(2);
    });

    it("Should not allow bettors to be added after the bet is closed", async function () {
      const { sigmaZero, owner, betInitiator, secondBettor } =
        await loadFixture(deployOneYearSigmaZeroFixture);

      await sigmaZero
        .connect(betInitiator)
        .placeBet(
          "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe",
          10,
          2,
          1000000000000000000n,
          {
            value: ethers.parseEther("1"),
          }
        );
      await sigmaZero.connect(owner).setBetValue(1, 2000, Date.now());
      await sigmaZero.connect(owner).closeBet(1);

      await expect(
        sigmaZero.connect(secondBettor).addBettor(1, 2, 2000000000000000000n, {
          value: ethers.parseEther("2"),
        })
      ).to.be.revertedWith("Bet is already closed");
    });

    it("Should allow the admin to calculate results and distribute winnings", async function () {
      const { sigmaZero, owner, betInitiator, secondBettor } =
        await loadFixture(deployOneYearSigmaZeroFixture);

      await sigmaZero
        .connect(betInitiator)
        .placeBet(
          "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe",
          10,
          2,
          1000000000000000000n,
          {
            value: ethers.parseEther("1"),
          }
        );
      await sigmaZero.connect(owner).setBetValue(1, 2000, Date.now());
      await sigmaZero
        .connect(secondBettor)
        .addBettor(1, 2, 2000000000000000000n, {
          value: ethers.parseEther("2"),
        });
      await sigmaZero.connect(owner).closeBet(1);
      await sigmaZero
        .connect(owner)
        .calculateResultsAndDistributeWinnings(1, 2000);

      const bet = await sigmaZero.bets(1);
      expect(bet.status).to.equal(3);
    });

    it("Should distribute the correct amount of winnings to all bettors", async function () {
      const { sigmaZero, owner, betInitiator, secondBettor } =
        await loadFixture(deployOneYearSigmaZeroFixture);

      await sigmaZero
        .connect(betInitiator)
        .placeBet(
          "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe",
          10,
          2,
          ethers.parseEther("1"),
          {
            value: ethers.parseEther("1"),
          }
        );
      await sigmaZero.connect(owner).setBetValue(1, 2000, Date.now());
      await sigmaZero
        .connect(secondBettor)
        .addBettor(1, 2, ethers.parseEther("2"), {
          value: ethers.parseEther("2"),
        });

      const betInitiatorBalanceAfterBet = await ethers.provider.getBalance(
        betInitiator.address
      );
      const secondBettorBalanceAfterBet = await ethers.provider.getBalance(
        secondBettor.address
      );

      await sigmaZero.connect(owner).closeBet(1);
      await sigmaZero
        .connect(owner)
        .calculateResultsAndDistributeWinnings(1, 2000);

      const bet = await sigmaZero.bets(1);
      expect(bet.status).to.equal(3);

      // Winner gets 1 ETH (betInitiator's wager) + 2 ETH (secondBettor's wager)
      expect(await ethers.provider.getBalance(betInitiator.address)).to.equal(
        betInitiatorBalanceAfterBet +
          ethers.parseEther("1") +
          ethers.parseEther("2")
      );
      // Loser gets nothing
      expect(await ethers.provider.getBalance(secondBettor.address)).to.equal(
        secondBettorBalanceAfterBet
      );
    });

    it("Should distribute the correct amount of winnings to all bettors (2 bettors on each side of the bet)", async function () {
      const {
        sigmaZero,
        owner,
        betInitiator,
        secondBettor,
        thirdBettor,
        fourthBettor,
      } = await loadFixture(deployOneYearSigmaZeroFixture);

      await sigmaZero
        .connect(betInitiator)
        .placeBet(
          "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe",
          10,
          2,
          ethers.parseEther("1"),
          {
            value: ethers.parseEther("1"),
          }
        );
      await sigmaZero.connect(owner).setBetValue(1, 2000, Date.now());
      await sigmaZero
        .connect(secondBettor)
        .addBettor(1, 1, ethers.parseEther("2"), {
          value: ethers.parseEther("2"),
        });
      await sigmaZero
        .connect(thirdBettor)
        .addBettor(1, 2, ethers.parseEther("3"), {
          value: ethers.parseEther("3"),
        });
      await sigmaZero
        .connect(fourthBettor)
        .addBettor(1, 2, ethers.parseEther("4"), {
          value: ethers.parseEther("4"),
        });

      const betInitiatorBalanceAfterBet = await ethers.provider.getBalance(
        betInitiator.address
      );
      const secondBettorBalanceAfterBet = await ethers.provider.getBalance(
        secondBettor.address
      );
      const thirdBettorBalanceAfterBet = await ethers.provider.getBalance(
        thirdBettor.address
      );
      const fourthBettorBalanceAfterBet = await ethers.provider.getBalance(
        fourthBettor.address
      );
      await sigmaZero.connect(owner).closeBet(1);
      await sigmaZero
        .connect(owner)
        .calculateResultsAndDistributeWinnings(1, 2000);

      const bet = await sigmaZero.bets(1);
      expect(bet.status).to.equal(3);

      // Winner gets 1 ETH (betInitiator's wager) + 1 ETH (1/3 thirdBettor's wager) + 1.33333 ETH (1/3 fourthBettor's wager)
      expect(await ethers.provider.getBalance(betInitiator.address)).to.equal(
        betInitiatorBalanceAfterBet +
          ethers.parseEther("1") +
          ethers.parseEther("1") +
          1333333333333333333n
      );
      // Winner gets 2 ETH (secondBettor's wager) + 2 ETH (2/3 thirdBettor's wager) + 2.6666 ETH (2/3 fourthBettor's wager/2)
      expect(await ethers.provider.getBalance(secondBettor.address)).to.equal(
        secondBettorBalanceAfterBet +
          ethers.parseEther("2") +
          ethers.parseEther("2") +
          2666666666666666666n
      );
      // Losers gets nothing
      expect(await ethers.provider.getBalance(thirdBettor.address)).to.equal(
        thirdBettorBalanceAfterBet
      );
      expect(await ethers.provider.getBalance(fourthBettor.address)).to.equal(
        fourthBettorBalanceAfterBet
      );
    });

    it("Should not allow the admin to calculate results and distribute winnings if the bet is not closed", async function () {
      const { sigmaZero, owner, betInitiator, secondBettor } =
        await loadFixture(deployOneYearSigmaZeroFixture);

      await sigmaZero
        .connect(betInitiator)
        .placeBet(
          "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe",
          10,
          2,
          ethers.parseEther("1"),
          {
            value: ethers.parseEther("1"),
          }
        );
      await sigmaZero.connect(owner).setBetValue(1, 2000, Date.now());
      await sigmaZero
        .connect(secondBettor)
        .addBettor(1, 2, ethers.parseEther("2"), {
          value: ethers.parseEther("2"),
        });

      await expect(
        sigmaZero.connect(owner).calculateResultsAndDistributeWinnings(1, 2000)
      ).to.be.revertedWith("Bet is not closed, cannot settle");
    });
  });
});
