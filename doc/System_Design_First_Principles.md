# System Design First Principles

1. Start with a proper understanding of the problem you have to solve with global (high level) definitions.

 **NOTE:** Avoid entering into specific use-cases at this stage.

2. Draw system boundaries - Are you about to design a general purpose system or
are you going to design a highly targeted and heavily constrained one:

    * General purpose system - **AVOID** including specific use-cases at this
    stage of the design process to the best you can.
    * Targeted system - **ALLOW** inclusion of specific use-cases in the early
    stages of the design process.

    **NOTE:** Basically, at this stage you decide how much would you allow the
            system to evolve in the future.

3. Define external systems interactions. Split them in categories:

    * Clients of the currently designed system
    * Systems to which the currently designed system would be a client.

4. Only then, start high level architecture design.

    **NOTE:** Do not go into deep details at this stage. Try to focus mostly on
        the modularity of the system and break it in purpose/functional pieces.

    **NOTE:** Here, you are still in the ***Qualitative*** phase of the design process

5. Start defining different abstractions and definitions of entities of the system.
e.g. Separation between *WorkLoad* vs. *WorkFlow* etc.

6. Based on the above, make the estimate of potential resource needs and internal
components interactions. Try to foresee eventual bottlenecks and single points of
failure at this stage.

    **NOTE:** Here, you enter the ***Quantitative*** phase of the design process.

7. **NOW** you start making technology choices!!!

    **NOTE:** Never allow the choice of technology to go before the above steps
    and become an end in itself. (BG: самоцел). Meaning, to wrap your whole design
    around the idea that you need to use a particular technology, and this act to
    start driving or influencing your future choices. This will be a recipe for
    future external dependence. And you would inevitably align the life cycle of
    your system with the life cycle of the tech choice you've made. In addition,
    you will constraint and strip yourself from future flexibility.
