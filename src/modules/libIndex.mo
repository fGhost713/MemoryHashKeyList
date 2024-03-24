import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import GlobalFunctions "../helpers/globalFunctions";
import CommonTypes "../types/commonTypes";
import Vector "mo:vector";

module libIndex = {

    private type MemoryStorage = CommonTypes.MemoryStorage;

    public func is_free_vector_available(memoryStorage : MemoryStorage) : Bool {
        Vector.size(memoryStorage.indizesPerKey_free) > 0;
    };

    public func empty_inner_vector(memoryStorage : MemoryStorage, outerIndex : Nat) {
        if (Vector.size(memoryStorage.indizesPerKey) > outerIndex) {
            let innerVector : Vector.Vector<Nat64> = Vector.get(memoryStorage.indizesPerKey, outerIndex);
            Vector.clear<Nat64>(innerVector);
            Vector.add(memoryStorage.indizesPerKey_free, outerIndex);
        };
    };

    public func add_outer_vector(memoryStorage : MemoryStorage) : Nat {
        if (is_free_vector_available(memoryStorage) == true) {
            let freeIndexOrNull : ?Nat = Vector.removeLast<Nat>(memoryStorage.indizesPerKey_free);
            switch (freeIndexOrNull) {
                case (?freeIndex) {
                    empty_inner_vector(memoryStorage, freeIndex);
                    return freeIndex;
                };
                case (_) {
                    // We need to create completely new vector
                    return create_completely_new_vector_internal(memoryStorage);
                };
            };

        } else {
            // add completely new vector
            return create_completely_new_vector_internal(memoryStorage);
        };
    };

    public func append_wrapped_blob_memory_address(memoryStorage : MemoryStorage, outerIndex : Nat, wrappedBlobAddress : Nat64) {
        let innerVector : Vector.Vector<Nat64> = Vector.get(memoryStorage.indizesPerKey, outerIndex);
        Vector.add<Nat64>(innerVector, wrappedBlobAddress);
    };

    public func remove_at_range(memoryStorage : MemoryStorage, outerIndex : Nat, startIndex : Nat, lastIndex : Nat) {

        let innerVectorOrNull = get_inner_vector(memoryStorage, outerIndex);
        switch (innerVectorOrNull) {
            case (?innerVector) {
                let vectorSize = Vector.size(innerVector);
                if (vectorSize == 0 or lastIndex < startIndex or startIndex >= vectorSize) {
                    return;
                };

                let lastIndexToUse = Nat.min(lastIndex, vectorSize -1);

                if (vectorSize > startIndex) {
                    let numbersToRemove : Nat = (lastIndexToUse - startIndex) + 1;

                    if (vectorSize == 1 and startIndex == 0) {
                        ignore Vector.removeLast(innerVector);
                        return;
                    };

                    for (index in Iter.range(startIndex + numbersToRemove, vectorSize -1)) {
                        let vecVal : Nat64 = Vector.get(innerVector, index);
                        let prevIndex : Nat = index - numbersToRemove;
                        Vector.put(innerVector, prevIndex, vecVal);
                    };
                    for (index in Iter.range(1, numbersToRemove)) {
                        ignore Vector.removeLast(innerVector);
                    };

                } else {

                };
            };
            case (_) {

                return;
            };
        };

    };

    // The performance is slow. (O(n))
    public func remove_at_index(memoryStorage : MemoryStorage, outerIndex : Nat, innerIndex : Nat) {

        //return remove_many_at_range(outerIndex, innerIndex, innerIndex);

        let innerVectorOrNull = get_inner_vector(memoryStorage, outerIndex);
        switch (innerVectorOrNull) {
            case (?innerVector) {
                let vectorSize = Vector.size(innerVector);
                if (vectorSize == 0) {
                    return;
                };

                if (vectorSize > innerIndex) {
                    if (vectorSize == 1) {
                        ignore Vector.removeLast(innerVector);
                        return;
                    };

                    for (index in Iter.range(innerIndex +1, vectorSize -1)) {
                        let vecVal : Nat64 = Vector.get(innerVector, index);
                        let prevIndex : Nat = index -1;
                        Vector.put(innerVector, prevIndex, vecVal);
                    };
                    ignore Vector.removeLast(innerVector);
                };

            };
            case (_) {
                return;
            };
        };
    };

    private func get_last_element(memoryStorage : MemoryStorage, vec : Vector.Vector<Nat64>) : ?Nat64 {

        let size : Nat = Vector.size(vec);
        if (size == 0) {
            return null;
        };

        Vector.getOpt<Nat64>(vec, size -1);
    };

    public func remove_last_element(memoryStorage : MemoryStorage, outerIndex : Nat) : ?Nat64 {
        let innerVectorOrNull = get_inner_vector(memoryStorage, outerIndex);
        switch (innerVectorOrNull) {
            case (?innerVector) {
                Vector.removeLast(innerVector);
            };
            case (_) {
                return null;
            };
        };

    };

    public func insert_many_at_index(memoryStorage : MemoryStorage, outerIndex : Nat, innerIndex : Nat, wrappedBlobAddresses : [Nat64]) {
        if (Array.size(wrappedBlobAddresses) == 0) {
            return;
        };

        let innerVectorOrNull = get_inner_vector(memoryStorage, outerIndex);
        switch (innerVectorOrNull) {
            case (?innerVector) {
                let vectorSize = Vector.size(innerVector);

                if (vectorSize == 0) {
                    if (innerIndex == 0) {
                        for (address : Nat64 in Iter.fromArray(wrappedBlobAddresses)) {
                            Vector.add<Nat64>(innerVector, address);
                        };
                    };
                    return;
                };

                if (vectorSize == 1) {
                    if (innerIndex == 0) {
                        let tempValue = Vector.get(innerVector, 0);
                        Vector.clear<Nat64>(innerVector);

                        for (address : Nat64 in Iter.fromArray(wrappedBlobAddresses)) {
                            Vector.add<Nat64>(innerVector, address);
                        };
                        Vector.add(innerVector, tempValue);
                    };
                    return;
                };

                if (vectorSize > innerIndex) {

                    // add dummy elements (will be overwritten later)
                    for (address : Nat64 in Iter.fromArray(wrappedBlobAddresses)) {
                        Vector.add<Nat64>(innerVector, 0);
                    };

                    // number of items to insert
                    let countNewItems : Nat = Array.size(wrappedBlobAddresses);

                    let vecLength = Vector.size(innerVector);

                    // set currIndex to last index
                    var currIndex : Nat = vecLength - countNewItems;

                    for (index in Iter.range(innerIndex, vectorSize - 1)) {
                        currIndex := currIndex - 1;
                        Vector.put(innerVector, currIndex + countNewItems, Vector.get(innerVector, currIndex));
                    };

                    currIndex := innerIndex;
                    for (address : Nat64 in Iter.fromArray(wrappedBlobAddresses)) {
                        Vector.put<Nat64>(innerVector, currIndex, address);
                        currIndex := currIndex + 1;
                    };
                };

            };
            case (_) {
                return;
            };
        };

    };

    // The performance is slow. (O(n))
    public func insert_at_index(memoryStorage : MemoryStorage, outerIndex : Nat, innerIndex : Nat, wrappedBlobAddress : Nat64) {
        return insert_many_at_index(memoryStorage, outerIndex, innerIndex, [wrappedBlobAddress]);

        let innerVectorOrNull = get_inner_vector(memoryStorage, outerIndex);
        switch (innerVectorOrNull) {
            case (?innerVector) {
                let vectorSize = Vector.size(innerVector);

                if (vectorSize == 0) {
                    if (innerIndex == 0) {
                        append_wrapped_blob_memory_address(memoryStorage, outerIndex, wrappedBlobAddress);
                    };
                    return;
                };

                if (vectorSize == 1) {
                    if (innerIndex == 0) {
                        let tempValue = Vector.get(innerVector, 0);
                        Vector.put(innerVector, 0, wrappedBlobAddress);
                        Vector.add(innerVector, tempValue);
                    };
                    return;
                };

                if (vectorSize > innerIndex) {

                    let lastElementOrNull = get_last_element(memoryStorage, innerVector);
                    switch (lastElementOrNull) {
                        case (?foundLastElement) {
                            // add dummy element (will be overwritten later)
                            Vector.add(innerVector, foundLastElement);
                        };
                        case (_) {
                            append_wrapped_blob_memory_address(memoryStorage, outerIndex, wrappedBlobAddress);
                            return;
                        };
                    };

                    var currIndex : Nat = vectorSize;

                    for (index in Iter.range(innerIndex, vectorSize -1)) {
                        currIndex := currIndex -1;
                        let vecVal = Vector.get(innerVector, currIndex);
                        let nextIndex : Nat = currIndex +1;
                        Vector.put(innerVector, nextIndex, vecVal);
                    };
                    Vector.put(innerVector, innerIndex, wrappedBlobAddress);
                };

            };
            case (_) {
                return;
            };
        };
    };

    public func get_address_of_last_stored_wrapped_blob(memoryStorage : MemoryStorage, outerIndex : Nat) : ?Nat64 {

        let innerVector_or_null : ?Vector.Vector<Nat64> = get_inner_vector(memoryStorage, outerIndex);
        switch (innerVector_or_null) {
            case (?innerVector) {

                let innerVectorSize : Nat = Vector.size(innerVector);

                if (innerVectorSize == 0) {
                    return null;
                };
                // return the last element
                return get_last_element(memoryStorage, innerVector);

            };
            case (_) {
                return null;
            };
        };

    };

    public func get_wrapped_blob_Address(memoryStorage : MemoryStorage, outerIndex : Nat, innerIndex : Nat) : ?Nat64 {
        let innerVector_or_null : ?Vector.Vector<Nat64> = get_inner_vector(memoryStorage, outerIndex);
        switch (innerVector_or_null) {
            case (?innerVector) {

                let result : ?Nat64 = Vector.getOpt(innerVector, innerIndex);
                return result;

            };
            case (_) {
                return null;
            };
        };
    };

    // return last index or null if empty
    public func get_last_index(memoryStorage : MemoryStorage, outerIndex : Nat) : ?Nat {

        let innerVector_or_null : ?Vector.Vector<Nat64> = get_inner_vector(memoryStorage, outerIndex);
        switch (innerVector_or_null) {
            case (?innerVector) {

                var result : Nat = Vector.size(innerVector);
                if (result == 0) {
                    return null;
                };
                result := result -1;
                return ?result;
            };
            case (_) {
                return null;
            };
        };

    };

    private func get_inner_vector(memoryStorage : MemoryStorage, outerIndex : Nat) : ?Vector.Vector<Nat64> {
        if (Vector.size(memoryStorage.indizesPerKey) <= outerIndex) {
            return null;
        };

        let innerVector : Vector.Vector<Nat64> = Vector.get(memoryStorage.indizesPerKey, outerIndex);
        return Option.make(innerVector);
    };

    private func create_completely_new_vector_internal(memoryStorage : MemoryStorage) : Nat {
        Vector.add(memoryStorage.indizesPerKey, Vector.new<Nat64>());
        return (Vector.size(memoryStorage.indizesPerKey) - 1);
    };

};
