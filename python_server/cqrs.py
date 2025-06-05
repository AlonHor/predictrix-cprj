from abc import ABC, abstractmethod


class Command(ABC):
    @abstractmethod
    def execute(self, *args, **kwargs):
        """
        Execute the command with the provided arguments.
        :param args: Positional arguments for the command.
        :param kwargs: Keyword arguments for the command.
        :return: Result of the command execution.
        """
        raise NotImplementedError("Subclasses should implement this method.")


class Query(ABC):
    @abstractmethod
    def execute(self, *args, **kwargs):
        """
        Execute the query with the provided arguments.
        :param args: Positional arguments for the query.
        :param kwargs: Keyword arguments for the query.
        :return: Result of the query execution.
        """
        raise NotImplementedError("Subclasses should implement this method.")
