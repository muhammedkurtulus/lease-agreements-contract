import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("LeaseContract", function () {
  it("Should deployer be owner and a manager", async function () {
    const { leaseContract, owner } = await loadFixture(init);
    expect(await leaseContract.owner()).to.equal(owner.address);
    expect(await leaseContract.isManager(owner.address)).to.equal(true);
  });

  it("Should add a new property", async function () {
    const { leaseContract, owner, addr1 } = await loadFixture(init);
    await leaseContract
      .connect(addr1)
      .addProperty(propertyAddress, PropertyType.House, name1);
    await leaseContract.addProperty(propertyAddress, PropertyType.Shop, name2);
    const properties = await leaseContract.getAllProperties();

    expect(properties).to.have.lengthOf(2);

    expect(properties[0].owner).to.equal(addr1.address);
    expect(properties[0].propertyType).to.equal(PropertyType.House);
    expect(properties[0].ownerName).to.equal(name1);
    expect(properties[0].propertyIndex).to.equal(0);

    expect(properties[1].owner).to.equal(owner.address);
    expect(properties[1].propertyType).to.equal(PropertyType.Shop);
    expect(properties[1].ownerName).to.equal(name2);
    expect(properties[1].propertyIndex).to.equal(1);
  });

  it("Should unlist a property", async function () {
    const { leaseContract, owner, addr1 } = await loadFixture(init);
    await leaseContract.addProperty(propertyAddress, PropertyType.House, name1);
    await leaseContract.unlistProperty(0);
    const properties = await leaseContract.getAllProperties();

    expect(properties).to.have.lengthOf(1);
    expect(properties[0].isListed).to.equal(false);
  });

  it("Should start a lease and sign", async function () {
    const { leaseContract, owner, addr1 } = await loadFixture(init);
    await leaseContract.addProperty(propertyAddress, PropertyType.House, name1);

    await leaseContract.startLease(0, addr1.address, name2, 2);

    const property = await leaseContract.properties(0);

    expect(property.leaseInfo.tenantAddress).to.equal(addr1.address);
    expect(property.leaseInfo.tenantName).to.equal(name2);
    expect(property.leaseInfo.duration).to.equal(2);
    expect(property.leaseInfo.isActive).to.equal(false);
    expect(property.leaseInfo.endDate - property.leaseInfo.startDate).to.equal(
      3 * day
    );

    await leaseContract.connect(addr1).signLease(0);

    const signedPropertyLease = await leaseContract.properties(0);

    expect(
      signedPropertyLease.leaseInfo.endDate - property.leaseInfo.startDate
    ).to.be.closeTo(2 * year, 1);
    expect(signedPropertyLease.leaseInfo.isActive).to.equal(true);
  });

  it("Should request termination by owner and confirm by manager", async function () {
    const { leaseContract, owner, addr1, addr2 } = await loadFixture(init);
    await leaseContract
      .connect(addr1)
      .addProperty(propertyAddress, PropertyType.House, name1);

    await leaseContract
      .connect(addr1)
      .startLease(0, addr2.address, "Tenant Name", 2);

    await leaseContract.connect(addr2).signLease(0);

    await leaseContract
      .connect(addr1)
      .requestTermination(0, ownerTerminateReason);

    await expect(
      leaseContract.confirmTermination(0)
    ).to.be.revertedWithCustomError(leaseContract, "NotPassed15Days");

    // const property = await leaseContract.properties(0);

    // expect(property.leaseInfo.isActive).to.equal(false);
    // expect(property.leaseInfo.terminationRequester).to.equal(addr1.address);
  });

  it("Should submit a complaint and confirm", async function () {
    const { leaseContract, owner, addr1, addr2 } = await loadFixture(init);
    await leaseContract
      .connect(addr1)
      .addProperty(propertyAddress, PropertyType.House, name1);

    await leaseContract
      .connect(addr1)
      .startLease(0, addr2.address, "Tenant Name", 2);

    await leaseContract.connect(addr2).signLease(0);

    await leaseContract
      .connect(addr1)
      .submitComplaint(0, addr2.address, ownerComplaintDescription);

    await leaseContract.reviewComplaint(0, addr2.address, true);

    const complaint = await leaseContract.complaints(addr2.address);

    expect(complaint.confirmed).to.equal(ConfirmationType.confirm);
  });
});

async function init() {
  const lease = await ethers.getContractFactory("Lease");
  const leaseContract = await lease.deploy();
  const [owner, addr1, addr2, addr3] = await ethers.getSigners();

  return { leaseContract, owner, addr1, addr2, addr3 };
}

enum PropertyType {
  House,
  Shop,
}

enum ConfirmationType {
  none,
  confirm,
  reject,
}

interface Complaint {
  complainant: string;
  whoAbout: string;
  propertyIndex: number;
  description: string;
  confirmed: ConfirmationType;
}

interface PropertyInfo {
  propertyAddress: string;
  owner: string;
  propertyType: PropertyType;
  ownerName: string;
  leaseInfo: LeaseInfo;
  isListed: boolean;
}

interface LeaseInfo {
  tenantAddress: string;
  tenantName: string;
  startDate: number;
  endDate: number;
  isActive: boolean;
  duration: number;
  terminationRequester: string;
  terminationReason: string;
  terminationRequestTime: number;
}

const propertyAddress = "Abc mah. No:1 Beypazari/Ankara";
const name1 = "Ali";
const name2 = "Veli";
const ownerTerminateReason = "I need the property back";
const tenantTerminateReason = "I need to move to another city";
const ownerComplaintDescription = "Owner is not maintaining the property";
const tenantComplaintDescription = "Tenant is not paying the rent";
const day = 60 * 60 * 24;
const year = 60 * 60 * 24 * 7 * 52;
