use starknet::{ContractAddress, get_caller_address};
use foundry::models::{position::{Position, Vec2}};
use foundry::models::machine::{
    Machine, MachineAtPosition, MachineType, ResourceType, Inventory, Direction
};

// define the interface
#[starknet::interface]
trait IActions<TContractState> {
    fn spawn(self: @TContractState);
    fn place_machine(
        self: @TContractState,
        machine_type: MachineType,
        resource_type: ResourceType,
        x: u32,
        y: u32,
        direction: Direction,
        connected_machines: Span<u32>
    ) -> u32;
    fn compute_inventory(self: @TContractState, id: u32) -> Inventory;
}

// dojo decorator
#[dojo::contract]
mod actions {
    use super::IActions;
    use debug::PrintTrait;

    use starknet::{ContractAddress, get_caller_address};
    use foundry::models::{position::{Position, Vec2}};
    use foundry::models::machine::{
        Machine, MachineTrait, MachineAtPosition, MachineType, ResourceType, Inventory, Direction
    };

    // impl: implement functions specified in trait
    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        // ContractState is defined by system decorator expansion
        fn spawn(self: @ContractState) {
            // Access the world dispatcher for reading.
            let world = self.world_dispatcher.read();

            // Get the address of the current caller, possibly the player's address.
            let player = get_caller_address();

            // Retrieve the player's current position from the world.
            let position = get!(world, player, (Position));

            set!(world, (Position { player, vec: Vec2 { x: 10, y: 10 } },));
        }

        fn place_machine(
            self: @ContractState,
            machine_type: MachineType,
            resource_type: ResourceType,
            x: u32,
            y: u32,
            direction: Direction,
            connected_machines: Span<u32>
        ) -> u32 {
            // Access the world dispatcher for reading.
            let world = self.world_dispatcher.read();
            let timestamp: u64 = starknet::get_block_info().unbox().block_timestamp;

            let current_machine = get!(world, (x, y), (MachineAtPosition));
            assert(current_machine.id == 0, 'There is something here');

            let machine_id = world.uuid() + 1;
            let mut machine: Machine = MachineTrait::new(
                machine_id, x, y, direction, machine_type, resource_type, timestamp
            );

            if machine_type == MachineType::Storage {
                assert(connected_machines.len() > 0, 'No connected machines');
                let isConnected: bool = *(@machine.try_connection(world, connected_machines));
                assert(isConnected, 'Connection failed');
                let source = connected_machines.get(connected_machines.len() - 1);
                machine.source = *(source.unwrap().unbox());
                machine.source_dist = connected_machines.len() - 1; // remove source machine
            }

            set!(world, (machine, MachineAtPosition { x, y, id: machine_id }));

            if machine_type == MachineType::Storage {
                self.compute_inventory(machine_id);
            }

            return machine_id;
        }

        fn compute_inventory(self: @ContractState, id: u32) -> Inventory {
            let timestamp: u64 = starknet::get_block_info().unbox().block_timestamp;
            let world = self.world_dispatcher.read();

            let (mut machine, mut inventory) = get!(world, id, (Machine, Inventory));
            assert(machine.machine_type != MachineType::None.into(), 'Machine not found');
            assert(machine.source != 0, 'Machine not connected');
            let source_machine = get!(world, machine.source, (Machine));

            machine.compute_inventory(ref inventory, @source_machine, timestamp);
            inventory.amount1.print();
            set!(world, (machine, inventory));
            return get!(world, id, (Inventory));
        }
    }
}
