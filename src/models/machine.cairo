use debug::PrintTrait;

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Eq)]
enum ResourceType {
    None,
    IronOre,
    IronIngot,
    IronPlate,
}

impl ResourceTypeInto of Into<ResourceType, u32> {
    fn into(self: ResourceType) -> u32 {
        match self {
            ResourceType::None => 0,
            ResourceType::IronOre => 1,
            ResourceType::IronIngot => 2,
            ResourceType::IronPlate => 3,
        }
    }
}

#[derive(Model, Drop, Serde)]
struct Machine {
    #[key]
    id: u32,
    x: u32,
    y: u32,
    machine_type: u32,
    direction: u32,
    source: u32,
    source_dist: u32,
    resource_type: u32,
    placed_at: u64,
    last_compute_at: u64,
}

#[derive(Model, Drop, Serde)]
struct Inventory {
    #[key]
    id: u32, // same as Machine id
    key1: u32,
    amount1: u32,
    key2: u32,
    amount2: u32,
    key3: u32,
    amount3: u32,
}

trait MachineTrait {
    fn new(
        id: u32,
        x: u32,
        y: u32,
        direction: Direction,
        machine_type: MachineType,
        resource_type: ResourceType,
        timestamp: u64,
    ) -> Machine;
    fn is_connected_to(self: @Machine, other: @Machine) -> bool;
    fn try_connection(ref self: Machine, world: IWorldDispatcher, path: Span<u32>) -> bool;
    fn compute_inventory(
        ref self: Machine, ref inventory: Inventory, source: @Machine, timestamp: u64
    );
}

impl MachineImpl of MachineTrait {
    fn new(
        id: u32,
        x: u32,
        y: u32,
        direction: Direction,
        machine_type: MachineType,
        resource_type: ResourceType,
        timestamp: u64,
    ) -> Machine {
        Machine {
            id,
            x,
            y,
            machine_type: machine_type.into(),
            direction: direction.into(),
            resource_type: resource_type.into(),
            source: 0,
            source_dist: 0,
            placed_at: timestamp,
            last_compute_at: timestamp,
        }
    }

    fn is_connected_to(self: @Machine, other: @Machine) -> bool {
        (self.direction == @Direction::Right.into() && *other.x > 0 && *other.x
            - 1 == *self.x && *other.y == *self.y)
            || (self.direction == @Direction::Left.into() && *other.x
                + 1 == *self.x && *other.y == *self.y)
            || (self.direction == @Direction::Down.into() && *other.x == *self.x && *other.y
                + 1 == *self.y)
            || (self.direction == @Direction::Up.into()
                && *other.y > 0
                && *other.x == *self.x
                && *other.y
                - 1 == *self.y)
    }

    fn try_connection(ref self: Machine, world: IWorldDispatcher, path: Span<u32>) -> bool {
        let mut i = 0;
        let mut current_machine = @self;
        loop {
            if i >= path.len() {
                break;
            }
            match path.get(i) {
                Option::Some(x) => {
                    let machine = get!(world, *x.unbox(), Machine);
                    if !machine.is_connected_to(current_machine) {
                        panic!("Not connected");
                    }
                    current_machine = @machine;
                },
                Option::None => { panic!("Not connected"); }
            }
            i += 1;
        };
        true
    }

    fn compute_inventory(
        ref self: Machine, ref inventory: Inventory, source: @Machine, timestamp: u64
    ) {
        let placed_at: u64 = self.placed_at;
        let last_compute_at: u64 = self.last_compute_at;
        let source_dist: u64 = self.source_dist.try_into().unwrap();

        assert(timestamp >= last_compute_at, 'Compute timestamp out of order');

        if (timestamp >= placed_at + source_dist) { // If resources reached the destination
            let mut diff = timestamp - last_compute_at;
            if last_compute_at < placed_at + source_dist {
                diff -= source_dist;
            }
            inventory.key1 = *source.resource_type;
            inventory.amount1 += diff.try_into().unwrap();
            self.last_compute_at = timestamp;
        }
    }
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Eq)]
enum MachineType {
    None,
    Producer,
    ConveyorBelt,
    Storage,
}

impl MachineTypeInto of Into<MachineType, u32> {
    fn into(self: MachineType) -> u32 {
        match self {
            MachineType::None => 0,
            MachineType::Producer => 1,
            MachineType::ConveyorBelt => 2,
            MachineType::Storage => 3,
        }
    }
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Eq)]
enum Direction {
    None,
    Up,
    Right,
    Down,
    Left,
}

impl DirectionInto of Into<Direction, u32> {
    fn into(self: Direction) -> u32 {
        match self {
            Direction::None => 0,
            Direction::Up => 1,
            Direction::Right => 2,
            Direction::Down => 3,
            Direction::Left => 4,
        }
    }
}

#[derive(Model, Drop, Serde)]
struct MachineAtPosition {
    #[key]
    x: u32,
    #[key]
    y: u32,
    id: u32,
}


#[cfg(test)]
mod tests {
    use starknet::class_hash::Felt252TryIntoClassHash;
    use array::ArrayTrait;

    use super::{Machine, MachineTrait, Direction, MachineType, ResourceType};

    #[test]
    #[available_gas(100000000)]
    fn test_is_connected_to() {
        let TIME = 1;
        let m1 = MachineTrait::new(
            1, 1000, 1000, Direction::Right, MachineType::Producer, ResourceType::IronOre, TIME
        );
        let m2 = MachineTrait::new(
            2, 1001, 1000, Direction::Right, MachineType::ConveyorBelt, ResourceType::None, TIME
        );
        assert(m1.is_connected_to(@m2), 'Should be connected right');

        let m1 = MachineTrait::new(
            1, 2000, 1000, Direction::Up, MachineType::Producer, ResourceType::IronOre, TIME
        );
        let m2 = MachineTrait::new(
            2, 2000, 1001, Direction::Up, MachineType::ConveyorBelt, ResourceType::None, TIME
        );
        assert(m1.is_connected_to(@m2), 'Should be connected up');

        let m1 = MachineTrait::new(
            1, 1000, 2000, Direction::Left, MachineType::Producer, ResourceType::IronOre, TIME
        );
        let m2 = MachineTrait::new(
            2, 999, 2000, Direction::Left, MachineType::ConveyorBelt, ResourceType::None, TIME
        );
        assert(m1.is_connected_to(@m2), 'Should be connected left');

        let m1 = MachineTrait::new(
            1, 2000, 2000, Direction::Down, MachineType::Producer, ResourceType::IronOre, TIME
        );
        let m2 = MachineTrait::new(
            2, 2000, 1999, Direction::Down, MachineType::ConveyorBelt, ResourceType::None, TIME
        );
        assert(m1.is_connected_to(@m2), 'Should be connected down');

        let m1 = MachineTrait::new(
            1, 3000, 1000, Direction::Right, MachineType::Producer, ResourceType::IronOre, TIME
        );
        let m2 = MachineTrait::new(
            2, 3001, 1000, Direction::Up, MachineType::ConveyorBelt, ResourceType::None, TIME
        );
        assert(m1.is_connected_to(@m2), 'Should be connected right-up');
    }

    #[test]
    #[available_gas(100000)]
    fn test_is_connected_to_error_direction() {
        let TIME = 1;
        let m1 = MachineTrait::new(
            1, 1000, 1000, Direction::Up, MachineType::Producer, ResourceType::IronOre, TIME
        );
        let m2 = MachineTrait::new(
            2, 1001, 1000, Direction::Right, MachineType::ConveyorBelt, ResourceType::None, TIME
        );

        assert(!m1.is_connected_to(@m2), 'Should not be connected')
    }

    #[test]
    #[available_gas(100000)]
    fn test_is_connected_to_error_pos() {
        let TIME = 1;
        let m1 = MachineTrait::new(
            1, 1000, 1000, Direction::Up, MachineType::Producer, ResourceType::IronOre, TIME
        );
        let m2 = MachineTrait::new(
            2, 1001, 1001, Direction::Right, MachineType::ConveyorBelt, ResourceType::None, TIME
        );

        assert(!m1.is_connected_to(@m2), 'Should not be connected')
    }
}
