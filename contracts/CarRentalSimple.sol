// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Simple Rental Marketplace (SmartRental)
/// @notice Clean version that matches your frontend and compiles correctly.

contract SmartRental {
    struct Car {
        uint256 id;
        address owner;
        string name;
        uint256 pricePerDayWei;
        bool available;
    }

    struct Rental {
        uint256 id;
        uint256 carId;
        address renter;
        uint256 paid;
        bool returned;
    }

    Car[] public cars;
    Rental[] public rentals;

    uint256 public totalRevenue;          // total ETH earned (in wei)
    uint256 public totalActiveRentals;    // tracks ongoing rentals

    event CarListed(uint256 indexed carId, address indexed owner, string name, uint256 price);
    event CarRented(uint256 indexed rentalId, uint256 indexed carId, address indexed renter, uint256 paid);
    event CarReturned(uint256 indexed rentalId, uint256 indexed carId);
    event Collected(uint256 indexed rentalId, address indexed owner, uint256 amount);

    // -------------------------------------------------------------
    // LIST CAR
    // -------------------------------------------------------------
    function listCar(string calldata name, uint256 pricePerDayWei) external returns (uint256) {
        uint256 id = cars.length;

        cars.push(Car({
            id: id,
            owner: msg.sender,
            name: name,
            pricePerDayWei: pricePerDayWei,
            available: true
        }));

        emit CarListed(id, msg.sender, name, pricePerDayWei);
        return id;
    }

    // -------------------------------------------------------------
    // RENT CAR
    // -------------------------------------------------------------
    function rentCar(uint256 carId, uint256 daysCount) external payable returns (uint256) {
        require(carId < cars.length, "Car does not exist");
        require(daysCount > 0, "Days must be > 0");

        Car storage c = cars[carId];
        require(c.available, "Car not available");

        uint256 total = c.pricePerDayWei * daysCount;
        require(msg.value == total, "Incorrect payment");

        // mark unavailable
        c.available = false;

        uint256 rentalId = rentals.length;

        rentals.push(Rental({
            id: rentalId,
            carId: carId,
            renter: msg.sender,
            paid: msg.value,
            returned: false
        }));

        totalRevenue += msg.value;
        totalActiveRentals += 1;

        emit CarRented(rentalId, carId, msg.sender, msg.value);
        return rentalId;
    }

    // -------------------------------------------------------------
    // RETURN CAR
    // -------------------------------------------------------------
    function returnCar(uint256 rentalId) external {
        require(rentalId < rentals.length, "Rental not found");

        Rental storage r = rentals[rentalId];
        require(!r.returned, "Already returned");
        require(r.renter == msg.sender, "Only renter can return");

        r.returned = true;

        // make car available again
        cars[r.carId].available = true;

        if (totalActiveRentals > 0) {
            totalActiveRentals -= 1;
        }

        emit CarReturned(rentalId, r.carId);
    }

    // -------------------------------------------------------------
    // COLLECT PAYMENT
    // -------------------------------------------------------------
    function collect(uint256 rentalId) external {
        require(rentalId < rentals.length, "Rental not found");

        Rental storage r = rentals[rentalId];
        require(r.returned, "Car not returned yet");

        Car storage c = cars[r.carId];
        require(c.owner == msg.sender, "Not car owner");

        uint256 amount = r.paid;
        require(amount > 0, "Nothing to collect");

        r.paid = 0; // prevent double-collect

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "Transfer failed");

        emit Collected(rentalId, msg.sender, amount);
    }

    // -------------------------------------------------------------
    // VIEW FUNCTIONS
    // -------------------------------------------------------------
    function getCar(uint256 carId)
        external
        view
        returns (uint256, address, string memory, uint256, bool)
    {
        require(carId < cars.length, "Car does not exist");
        Car storage c = cars[carId];
        return (c.id, c.owner, c.name, c.pricePerDayWei, c.available);
    }

    function getRental(uint256 rentalId)
        external
        view
        returns (uint256, uint256, address, uint256, bool)
    {
        require(rentalId < rentals.length, "Rental not exist");
        Rental storage r = rentals[rentalId];
        return (r.id, r.carId, r.renter, r.paid, r.returned);
    }

    function totalCars() external view returns (uint256) {
        return cars.length;
    }

    // NOTE:
    // totalActiveRentals() function WAS REMOVED
    // because the public variable already provides the getter automatically:
    //
    // uint256 public totalActiveRentals;
    //
    // So calling totalActiveRentals() still works!
}
