#[cfg(test)]
mod tests {
    use starknet::class_hash::Felt252TryIntoClassHash;
    use array::ArrayTrait;

    // import world dispatcher
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // import test utils
    use dojo::test_utils::{spawn_test_world, deploy_contract};

    // import test utils
    use foundry::{
        systems::{actions::{actions, IActionsDispatcher, IActionsDispatcherTrait}},
        models::{
            position::{Position, Vec2, position},
            machine::{Machine, MachineAtPosition, MachineType, Direction, ResourceType, machine}
        },
    };

    #[test]
    #[available_gas(30000000)]
    fn test_spawn() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // models
        let mut models = array![position::TEST_CLASS_HASH];

        // deploy world with models
        let world = spawn_test_world(models);

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        // call spawn()
        actions_system.spawn();
    }

    #[test]
    #[available_gas(30000000)]
    fn test_place_machine() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // models
        let mut models = array![position::TEST_CLASS_HASH];

        // deploy world with models
        let world = spawn_test_world(models);

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        actions_system
            .place_machine(
                MachineType::Producer,
                ResourceType::IronOre,
                1000,
                1000,
                Direction::Down,
                array![].span()
            );
    }

    #[test]
    #[available_gas(30000000)]
    #[should_panic]
    fn test_cant_place_machine() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // models
        let mut models = array![position::TEST_CLASS_HASH, machine::TEST_CLASS_HASH];

        // deploy world with models
        let world = spawn_test_world(models);

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        actions_system
            .place_machine(
                MachineType::Producer,
                ResourceType::IronOre,
                1000,
                1000,
                Direction::Down,
                array![].span()
            );

        // should panic
        actions_system
            .place_machine(
                MachineType::Storage,
                ResourceType::None,
                1000,
                1000,
                Direction::Down,
                array![].span()
            );
    }

    #[test]
    #[available_gas(100000000)]
    fn test_connect_machines() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // models
        let mut models = array![position::TEST_CLASS_HASH, machine::TEST_CLASS_HASH];

        // deploy world with models
        let world = spawn_test_world(models);

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        let producer_id = actions_system
            .place_machine(
                MachineType::Producer,
                ResourceType::IronOre,
                1000,
                1000,
                Direction::Right,
                array![].span()
            );

        let cb_id = actions_system
            .place_machine(
                MachineType::ConveyorBelt,
                ResourceType::None,
                1001,
                1000,
                Direction::Right,
                array![].span()
            );

        let storage_id = actions_system
            .place_machine(
                MachineType::Storage,
                ResourceType::None,
                1002,
                1000,
                Direction::Down,
                array![cb_id, producer_id].span()
            );

        let dispenser_at_position = get!(world, (1002, 1000), MachineAtPosition);
        assert(dispenser_at_position.id == storage_id, 'Dispenser not found');

        let dispenser = get!(world, storage_id, Machine);
        assert(dispenser.x == 1002 && dispenser.y == 1000, 'Dispenser not placed');
        assert(dispenser.source == producer_id, 'Producer not connected');
        assert(dispenser.source_dist == 1, 'Producer not connected');
    }

    #[test]
    #[available_gas(30000000)]
    #[should_panic]
    fn test_connect_machines_error_not_aligned() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // models
        let mut models = array![position::TEST_CLASS_HASH, machine::TEST_CLASS_HASH];

        // deploy world with models
        let world = spawn_test_world(models);

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        let producer_id = actions_system
            .place_machine(
                MachineType::Producer,
                ResourceType::IronOre,
                1000,
                1000,
                Direction::Right,
                array![].span()
            );

        let cb_id = actions_system
            .place_machine(
                MachineType::ConveyorBelt,
                ResourceType::None,
                1001,
                1000,
                Direction::Down,
                array![].span()
            );

        let storage_id = actions_system
            .place_machine(
                MachineType::Storage,
                ResourceType::None,
                1002,
                1000,
                Direction::Down,
                array![cb_id, producer_id].span()
            );
    }

    #[test]
    #[available_gas(100000000)]
    #[should_panic]
    fn test_connect_machines_error_not_connected() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // models
        let mut models = array![position::TEST_CLASS_HASH, machine::TEST_CLASS_HASH];

        // deploy world with models
        let world = spawn_test_world(models);

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        let producer_id = actions_system
            .place_machine(
                MachineType::Producer,
                ResourceType::IronOre,
                1000,
                1000,
                Direction::Right,
                array![].span()
            );

        let cb_id = actions_system
            .place_machine(
                MachineType::ConveyorBelt,
                ResourceType::None,
                1001,
                1002,
                Direction::Down,
                array![].span()
            );

        let storage_id = actions_system
            .place_machine(
                MachineType::Storage,
                ResourceType::None,
                1002,
                1000,
                Direction::Down,
                array![cb_id, producer_id].span()
            );
    }

    #[test]
    #[available_gas(100000000)]
    #[should_panic]
    fn test_connect_machines_error_no_conveyorbelt() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // models
        let mut models = array![position::TEST_CLASS_HASH, machine::TEST_CLASS_HASH];

        // deploy world with models
        let world = spawn_test_world(models);

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        let producer_id = actions_system
            .place_machine(
                MachineType::Producer,
                ResourceType::IronOre,
                1000,
                1000,
                Direction::Right,
                array![].span()
            );

        let cb_id = actions_system
            .place_machine(
                MachineType::ConveyorBelt,
                ResourceType::None,
                1006,
                1002,
                Direction::Right,
                array![].span()
            );

        let storage_id = actions_system
            .place_machine(
                MachineType::Storage,
                ResourceType::None,
                1002,
                1000,
                Direction::Down,
                array![cb_id, producer_id].span()
            );
    }

    #[test]
    #[available_gas(100000000)]
    fn test_connect_machines_and_gather() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // models
        let mut models = array![position::TEST_CLASS_HASH, machine::TEST_CLASS_HASH];

        // deploy world with models
        let world = spawn_test_world(models);

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        let producer_id = actions_system
            .place_machine(
                MachineType::Producer,
                ResourceType::IronOre,
                1000,
                1000,
                Direction::Right,
                array![].span()
            );

        let cb_id = actions_system
            .place_machine(
                MachineType::ConveyorBelt,
                ResourceType::None,
                1001,
                1000,
                Direction::Right,
                array![].span()
            );

        let storage_id = actions_system
            .place_machine(
                MachineType::Storage,
                ResourceType::None,
                1002,
                1000,
                Direction::Down,
                array![cb_id, producer_id].span()
            );

        let inventory = actions_system.compute_inventory(storage_id);
        assert(inventory.key1 == 0, 'Not IronOre');
        assert(inventory.amount1 == 0, 'Not right amount');
    }

    #[test]
    #[available_gas(50000000)]
    #[should_panic]
    fn test_connect_machines_no_connected_machines() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // models
        let mut models = array![position::TEST_CLASS_HASH, machine::TEST_CLASS_HASH];

        // deploy world with models
        let world = spawn_test_world(models);

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        let producer_id = actions_system
            .place_machine(
                MachineType::Producer,
                ResourceType::IronOre,
                1000,
                1000,
                Direction::Right,
                array![].span()
            );

        let cb_id = actions_system
            .place_machine(
                MachineType::ConveyorBelt,
                ResourceType::None,
                1001,
                1000,
                Direction::Right,
                array![].span()
            );

        let storage_id = actions_system
            .place_machine(
                MachineType::Storage,
                ResourceType::None,
                1002,
                1000,
                Direction::Down,
                array![].span()
            );
    }

    #[test]
    #[available_gas(50000000)]
    #[should_panic]
    fn test_place_storage_error_no_connection() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // models
        let mut models = array![position::TEST_CLASS_HASH, machine::TEST_CLASS_HASH];

        // deploy world with models
        let world = spawn_test_world(models);

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        let storage_id = actions_system
            .place_machine(
                MachineType::Storage,
                ResourceType::None,
                1010,
                1010,
                Direction::Right,
                array![].span()
            );
    }

    #[test]
    #[available_gas(50000000)]
    #[should_panic]
    fn test_place_storage_error_wrong_connection() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // models
        let mut models = array![position::TEST_CLASS_HASH, machine::TEST_CLASS_HASH];

        // deploy world with models
        let world = spawn_test_world(models);

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        let storage_id = actions_system
            .place_machine(
                MachineType::Storage,
                ResourceType::None,
                1009,
                1018,
                Direction::Up,
                array![3, 2, 1].span()
            );
    }
}
