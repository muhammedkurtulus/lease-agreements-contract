import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

enum PropertyType {
  House,
  Shop,
}

describe("LeaseContract", function () {
  async function deployLeaseFixture() {
    const lease = await ethers.getContractFactory("LeaseContract");
    const leaseContract = await lease.deploy();
    const [owner, tenant] = await ethers.getSigners();

    return { leaseContract, owner, tenant };
  }

  it("should add property", async function () {
    const { leaseContract, owner } = await loadFixture(deployLeaseFixture);
    const propertyAddress = "Ayvasik mah. No:1 Beypazari/Ankara";
    const propertyType = PropertyType.House;
    const ownerName = "Ali";

    await leaseContract.addProperty(propertyAddress, propertyType, ownerName);

    const properties = await leaseContract.getOwnerProperties();
    expect(properties).to.have.lengthOf(1);

    const addedProperty = properties[0];
    expect(addedProperty.owner).to.equal(owner.address);
    expect(addedProperty.propertyType).to.equal(propertyType);
    expect(addedProperty.ownerName).to.equal(ownerName);
    expect(addedProperty.leaseInfo.tenantAddress).to.equal(ethers.ZeroAddress);
  });

  it("should start lease", async function () {
    const { leaseContract, owner, tenant } = await loadFixture(
      deployLeaseFixture
    );
    const propertyAddress = "Ayvasik mah. No:1 Beypazari/Ankara";
    const propertyType = PropertyType.House;
    const ownerName = "Ali";
    const tenantName = "Veli";
    const startDate = Math.floor(Date.now() / 1000);
    const endDate = startDate + 86400;

    await leaseContract.addProperty(propertyAddress, propertyType, ownerName);

    await leaseContract.startLease(
      propertyAddress,
      tenant.address,
      tenantName,
      startDate,
      endDate
    );

    const addedProperty = await leaseContract.getPropertyInfo(propertyAddress);
    expect(addedProperty.leaseInfo.tenantAddress).to.equal(tenant.address);
    expect(addedProperty.leaseInfo.tenantName).to.equal(tenantName);
    expect(addedProperty.leaseInfo.startDate).to.equal(startDate);
    expect(addedProperty.leaseInfo.endDate).to.equal(endDate);
  });

  it("should end lease", async function () {
    const { leaseContract, owner, tenant } = await loadFixture(
      deployLeaseFixture
    );
    const propertyAddress = "Ayvasik mah. No:1 Beypazari/Ankara";
    const propertyType = PropertyType.House;
    const ownerName = "Ali";
    const tenantName = "Veli";
    const startDate = Math.floor(Date.now() / 1000);
    const endDate = startDate + 86400;

    await leaseContract.addProperty(propertyAddress, propertyType, ownerName);

    await leaseContract.startLease(
      propertyAddress,
      tenant.address,
      tenantName,
      startDate,
      endDate
    );

    await leaseContract.endLease(propertyAddress);

    const addedProperty = await leaseContract.getPropertyInfo(propertyAddress);
    expect(addedProperty.leaseInfo.tenantAddress).to.equal(ethers.ZeroAddress);
    expect(addedProperty.leaseInfo.tenantName).to.equal("");
    expect(addedProperty.leaseInfo.startDate).to.equal(0);
    expect(addedProperty.leaseInfo.endDate).to.equal(0);
  });

  it("should get owner properties", async function () {
    const { leaseContract, owner } = await loadFixture(deployLeaseFixture);

    const properties = await leaseContract.getOwnerProperties();

    for (const property of properties) {
      expect(property.owner).to.equal(owner.address);
    }
  });
});
